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

-- Frecuencia funcional para actividades repetitivas (RF-03).
CREATE TYPE frecuencia_enum AS ENUM ('diaria', 'semanal', 'mensual', 'anual');
-- Define si una actividad fue creada localmente o importada de Google Calendar.
CREATE TYPE activity_source_enum AS ENUM ('local', 'google');
-- Estado estandar compatible con eventos de Google Calendar.
CREATE TYPE activity_status_enum AS ENUM ('confirmed', 'tentative', 'cancelled');

-- Usuarios del sistema: mantiene compatibilidad local y vinculacion con Clerk.
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ID externo del proveedor Clerk para autenticar en backend.
    clerk_user_id VARCHAR(255) UNIQUE,
    correo VARCHAR(255) UNIQUE,
    contrasenna VARCHAR(255),
    nombre VARCHAR(255),
    -- Campo legado mantenido para compatibilidad temporal con codigo actual.
    token_google VARCHAR(2048),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Credenciales OAuth por usuario para acceder a Google Calendar.
CREATE TABLE user_google_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Relacion 1 a 1: un usuario local tiene una conexion Google activa.
    id_usuario UUID NOT NULL UNIQUE,
    google_email VARCHAR(255),
    google_account_sub VARCHAR(255),
    -- Guardan sesion OAuth; idealmente deben almacenarse cifrados.
    access_token TEXT,
    refresh_token TEXT,
    token_type VARCHAR(50),
    scope TEXT,
    expires_at TIMESTAMPTZ,
    -- Permite desconectar sin perder historico.
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_user_google_connections_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Estado tecnico de sincronizacion incremental con Google por usuario.
CREATE TABLE user_google_sync_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL UNIQUE,
    -- Normalmente 'primary', pero deja abierta la opcion de multi-calendario.
    google_calendar_id VARCHAR(255) NOT NULL DEFAULT 'primary',
    -- Token que entrega Google para sincronizaciones incrementales.
    sync_token TEXT,
    last_synced_at TIMESTAMPTZ,
    last_successful_sync_at TIMESTAMPTZ,
    -- Ultimo error para auditoria y debugging de sincronizacion.
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
CREATE TABLE prioridad (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad UUID NOT NULL,
    valor VARCHAR(255),
    color VARCHAR(7),
    CONSTRAINT fk_prioridad_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_prioridad_id_actividad
    ON prioridad(id_actividad);

-- Preferencias de horario del usuario para planificacion.
CREATE TABLE ajustes_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    ocupacion VARCHAR(50),
    hora_inicio INTEGER,
    hora_fin INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ajustes_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Garantiza un solo registro de ajustes por usuario.
CREATE UNIQUE INDEX uq_ajustes_usuario_id_usuario
    ON ajustes_usuario(id_usuario);

