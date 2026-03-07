-- Habilita funciones criptograficas y utilidades como gen_random_uuid().
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Limpia tablas auxiliares de integracion Google primero por dependencias.
DROP TABLE IF EXISTS user_google_sync_state CASCADE;
DROP TABLE IF EXISTS user_google_connections CASCADE;
-- Limpia tablas del dominio principal de actividades.
DROP TABLE IF EXISTS prioridad CASCADE;
DROP TABLE IF EXISTS repeticiones CASCADE;
DROP TABLE IF EXISTS actividades_detalles CASCADE;
DROP TABLE IF EXISTS actividades CASCADE;
DROP TABLE IF EXISTS etiquetas CASCADE;
DROP TABLE IF EXISTS ajustes_usuario CASCADE;
DROP TABLE IF EXISTS frecuencia CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
-- Limpia tipos enumerados para recrearlos de forma consistente.
DROP TYPE IF EXISTS frecuencia_enum;
DROP TYPE IF EXISTS activity_source_enum;
DROP TYPE IF EXISTS activity_status_enum;
DROP TYPE IF EXISTS priority_value_enum;

-- Frecuencia funcional para actividades repetitivas (RF-03).
CREATE TYPE frecuencia_enum AS ENUM ('diaria', 'semanal', 'mensual', 'anual');
-- Valores de prioridad para actividades (RF-03).
CREATE TYPE priority_value_enum AS ENUM ('baja', 'media', 'alta');
-- Define si una actividad fue creada localmente o importada de Google Calendar.
CREATE TYPE activity_source_enum AS ENUM ('local', 'google');
-- Estado estandar compatible con eventos de Google Calendar.
CREATE TYPE activity_status_enum AS ENUM ('confirmed', 'tentative', 'cancelled');

-- Usuarios del sistema: se registran/sincronizan al hacer login con Clerk.
-- FLUJO: Login con Clerk -> obtener clerk_user_id, correo y nombre desde Clerk -> guardar en tabla usuarios.
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ID externo y unico de Clerk (obtenido durante login).
    clerk_user_id VARCHAR(255) UNIQUE NOT NULL,
    -- Correo obtenido del login Clerk (no editable desde UI del app).
    correo VARCHAR(255) UNIQUE,
    -- Contrasenna almacenada de forma segura (no usado en login Clerk, solo para compatibilidad legacy).
    contrasenna VARCHAR(255),
    -- Nombre obtenido del login Clerk (no editable desde UI del app).
    nombre VARCHAR(255),
    -- Token de acceso a Google Calendar (se genera durante vinculacion OAuth).
    token_google VARCHAR(2048),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Credenciales OAuth para acceder a Google Calendar (asignadas durante vinculacion Google).
CREATE TABLE user_google_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Relacion 1 a 1 con usuario: un usuario tiene una conexion Google activa.
    id_usuario UUID NOT NULL UNIQUE,
    google_email VARCHAR(255),
    google_account_sub VARCHAR(255),
    -- Tokens de sesion OAuth (guardar cifrados en produccion).
    access_token TEXT,
    refresh_token TEXT,
    token_type VARCHAR(50),
    scope TEXT,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_user_google_connections_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Estado tecnico para sincronizacion incremental de eventos con Google Calendar.
CREATE TABLE user_google_sync_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL UNIQUE,
    -- ID del calendario Google (normalmente 'primary' para el calendario principal).
    google_calendar_id VARCHAR(255) NOT NULL DEFAULT 'primary',
    -- Token para sincronizaciones incrementales desde Google.
    sync_token TEXT,
    last_synced_at TIMESTAMPTZ,
    last_successful_sync_at TIMESTAMPTZ,
    -- Ultimo error de sync para debugging.
    last_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_user_google_sync_state_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Etiquetas visuales para organizar actividades por usuario.
CREATE TABLE etiquetas (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario UUID NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    color VARCHAR(7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_etiquetas_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Tabla principal de actividades (locales y sincronizadas desde Google).
CREATE TABLE actividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ID legado usado por la API actual (no confundir con clerk_user_id).
    id_clerk VARCHAR(255),
    id_etiqueta INTEGER,
    id_usuario UUID NOT NULL,
    -- ID real del evento en Google Calendar para evitar duplicados en sync.
    google_event_id VARCHAR(255),
    google_calendar_id VARCHAR(255) NOT NULL DEFAULT 'primary',
    source activity_source_enum NOT NULL DEFAULT 'local',
    status activity_status_enum NOT NULL DEFAULT 'confirmed',

    -- Campos funcionales RF-03 (fechas y horas de la actividad).
    fecha_inicio DATE,
    fecha_fin DATE,
    hora_inicio TIME,
    hora_fin TIME,

    -- Campos normalizados para interoperar con APIs externas y consultas.
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    start_timezone VARCHAR(64),
    end_timezone VARCHAR(64),

    -- RF-03: tiempo de descanso y tiempo muerto (traslados, etc.).
    tiempo_descanso_min INTEGER,
    tiempo_muerto_min INTEGER,

    -- Soporte para eventos de dia completo.
    is_all_day BOOLEAN NOT NULL DEFAULT FALSE,

    -- Metadatos de origen/sincronizacion con Google Calendar.
    event_created_at TIMESTAMPTZ,
    event_updated_at TIMESTAMPTZ,
    last_synced_at TIMESTAMPTZ,

    -- Campo legado usado por consultas existentes (compatibilidad).
    fecha_creacion VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_actividades_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE,
    CONSTRAINT fk_actividades_etiqueta
        FOREIGN KEY (id_etiqueta) REFERENCES etiquetas(id) ON DELETE SET NULL,
    CONSTRAINT uq_actividades_google_event
        UNIQUE (id_usuario, google_calendar_id, google_event_id)
);

-- Aceleran consultas por usuario, fecha y sincronizacion.
CREATE INDEX idx_actividades_usuario ON actividades(id_usuario);
CREATE INDEX idx_actividades_usuario_fecha ON actividades(id_usuario, fecha_creacion);
CREATE INDEX idx_actividades_usuario_start ON actividades(id_usuario, start_datetime);
CREATE INDEX idx_actividades_google_event ON actividades(id_usuario, google_event_id);

-- Detalles descriptivos de cada actividad.
CREATE TABLE actividades_detalles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    descripcion TEXT,
    -- Ubicacion solicitada en RF-03.
    ubicacion VARCHAR(255),

    -- Enlaces y metadatos extra de Google Calendar.
    html_link VARCHAR(1024),
    meeting_link VARCHAR(1024),
    organizer_email VARCHAR(255),
    -- Payload original opcional para auditoria/depuracion.
    raw_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_actividades_detalles_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_actividades_detalles_id_actividad
    ON actividades_detalles(id_actividad);

-- Catalogo de frecuencias permitidas para repeticion.
CREATE TABLE frecuencia (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    frecuencia frecuencia_enum NOT NULL
);

-- Configuracion de repeticion por actividad.
CREATE TABLE repeticiones (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_frecuencia INTEGER,
    -- Ejemplo: MON,TUE,FRI cuando aplica frecuencia semanal.
    dias_semana VARCHAR(25),
    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ,
    id_actividad UUID NOT NULL,
    -- Regla RFC5545 (RRULE) para compatibilidad con Google Calendar.
    recurrence_rule TEXT,
    CONSTRAINT fk_repeticiones_frecuencia
        FOREIGN KEY (id_frecuencia) REFERENCES frecuencia(id) ON DELETE SET NULL,
    CONSTRAINT fk_repeticiones_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_repeticiones_id_actividad
    ON repeticiones(id_actividad);

-- Prioridad/Importancia de la actividad (RF-03).
-- FLUJO: Se crea cuando se genera una actividad. El usuario selecciona nivel de prioridad (baja/media/alta).
CREATE TABLE prioridad (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad UUID NOT NULL,
    -- Nivel de prioridad: baja, media o alta (seleccionado por usuario al crear actividad).
    valor priority_value_enum NOT NULL DEFAULT 'media',
    -- Color asociado para visualizacion en UI (ej: rojo para alta, amarillo para media, verde para baja).
    color VARCHAR(7),
    CONSTRAINT fk_prioridad_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_prioridad_id_actividad
    ON prioridad(id_actividad);

-- Preferencias y configuracion del usuario (segundo formulario post-login).
-- FLUJO: Despues del login Clerk, el usuario completa este formulario UNA SOLA VEZ.
-- Solo puede editar: ocupacion. Las horas de suenno NO son editables desde UI.
CREATE TABLE ajustes_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    -- Ocupacion del usuario (ingresada por el usuario en formulario post-login).
    ocupacion VARCHAR(50),
    -- Hora de inicio de suenno (no modificable desde UI, system-managed).
    -- Ejemplo: 22 (10 PM) - fuera de este horario el sistema puede sugerir actividades.
    hora_inicio INTEGER,
    -- Hora de fin de suenno (no modificable desde UI, system-managed).
    -- Ejemplo: 7 (7 AM) - fuera de este horario el sistema puede sugerir actividades.
    hora_fin INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ajustes_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Garantiza un solo registro de ajustes por usuario.
CREATE UNIQUE INDEX uq_ajustes_usuario_id_usuario
    ON ajustes_usuario(id_usuario);

