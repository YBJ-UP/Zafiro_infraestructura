DROP TABLE IF EXISTS prioridad CASCADE;
DROP TABLE IF EXISTS repeticiones CASCADE;
DROP TABLE IF EXISTS actividades_detalles CASCADE;
DROP TABLE IF EXISTS actividades CASCADE;
DROP TABLE IF EXISTS etiquetas CASCADE;
DROP TABLE IF EXISTS frecuencia CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TYPE IF EXISTS frecuencia_enum;

CREATE TYPE frecuencia_enum AS ENUM ('diaria', 'semanal', 'mensual', 'anual');

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correo VARCHAR(255),
    contrasenna VARCHAR(255),
    nombre VARCHAR(255),
    token_google VARCHAR(255)
);

CREATE TABLE etiquetas (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario UUID,
    nombre VARCHAR(50),
    color VARCHAR(7),
    CONSTRAINT fk_etiquetas_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
);

CREATE TABLE actividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_clerk INTEGER,
    id_etiqueta INTEGER,
    id_usuario UUID,
    fecha_creacion VARCHAR(255),
    CONSTRAINT fk_actividades_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id),
    CONSTRAINT fk_actividades_etiqueta
        FOREIGN KEY (id_etiqueta) REFERENCES etiquetas(id)
);

CREATE TABLE actividades_detalles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad UUID,
    title VARCHAR(255),
    descripcion VARCHAR(255),
    ubicacion VARCHAR(255),
    CONSTRAINT fk_actividades_detalles_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id)
);

CREATE TABLE frecuencia (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    frecuencia frecuencia_enum
);

CREATE TABLE repeticiones (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_frecuencia INTEGER,
    dias_semana VARCHAR(25),
    fecha_inicio TIMESTAMP,
    fecha_fin TIMESTAMP,
    id_actividad UUID,
    CONSTRAINT fk_repeticiones_frecuencia
        FOREIGN KEY (id_frecuencia) REFERENCES frecuencia(id),
    CONSTRAINT fk_repeticiones_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id)
);

CREATE TABLE prioridad (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad UUID,
    valor VARCHAR(255),
    color VARCHAR(7),
    CONSTRAINT fk_prioridad_actividad
        FOREIGN KEY (id_actividad) REFERENCES actividades(id)
);

CREATE TABLE ajustes_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID,
    ocupacion VARCHAR(10),
    hora_inicio INTEGER,
    hora_fin INTEGER,
    CONSTRAINT fk_ajustes_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
);

