CREATE TABLE usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(25),
    contrasenna VARCHAR(255),
    hora_dormir TIMESTAMP,
    hora_despertar TIMESTAMP,
    hora_entrada TIMESTAMP,
    hora_salida TIMESTAMP
);

CREATE TABLE etiqueta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID REFERENCES usuario(id),
    nombre VARCHAR(25),
    color VARCHAR(7)
);

CREATE TABLE prioridad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID REFERENCES usuario(id),
    nombre VARCHAR(25),
    colores VARCHAR(7)
);

CREATE TABLE frecuencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID REFERENCES usuario(id),
    nombre VARCHAR(25)
);

CREATE TABLE actividad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID REFERENCES usuario(id),
    id_etiqueta UUID REFERENCES  etiqueta(id),
    hora_inicio TIMESTAMP,
    hora_fin TIMESTAMP
);

CREATE TABLE actividad_detalles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_actividad UUID REFERENCES actividad(id),
    titulo VARCHAR(100),
    descripcion TEXT,
    tipo VARCHAR(50),
    ubicacion TEXT
);

