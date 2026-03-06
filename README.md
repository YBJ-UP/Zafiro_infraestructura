# Infraestructura del proyecto Zafiro

Este repositorio contiene la infraestructura de base de datos del proyecto Zafiro, con soporte para desarrollo local mediante Docker Compose y despliegue en Supabase.

## 🚀 Desarrollo Local

Para ejecutar la base de datos localmente con Docker:

```bash
docker compose up --build
```

Esto iniciará una instancia de PostgreSQL 16 con todos los esquemas y datos iniciales.

### Variables de Entorno

Copia el archivo `.env.example` a `.env` y ajusta los valores según sea necesario:

```bash
cp .env.example .env
```

## ☁️ Despliegue en Supabase

Este proyecto está configurado para sincronizarse automáticamente con Supabase.

### Configuración Inicial

1. **Instala el CLI de Supabase** (si no lo tienes):
   ```bash
   npm install -g supabase
   ```

2. **Vincula tu proyecto** (primera vez):
   ```bash
   npx supabase link --project-ref bdbaagrjlsuibhvbzuwx
   ```

3. **Sincroniza los cambios**:
   ```bash
   npx supabase db push
   ```

### Sincronización Automática con GitHub Actions

El workflow de GitHub Actions (`.github/workflows/database-sync.yml`) se encarga de sincronizar automáticamente los cambios de la base de datos con Supabase cuando:
- Haces push a la rama `main`
- Hay cambios en la carpeta `db/`

**Configuración requerida**: Ver [.github/workflows/README.md](.github/workflows/README.md) para instrucciones sobre cómo configurar los secretos de GitHub.

## 📁 Estructura de la Base de Datos

Los archivos SQL en la carpeta `db/` se ejecutan en orden:

1. **1-schema.sql** - Esquema de la base de datos (tablas, tipos, etc.)
2. **2-indexes.sql** - Índices para optimizar consultas
3. **3-seed.sql** - Datos iniciales para desarrollo
4. **4-views.sql** - Vistas de base de datos
5. **5-migrate.sql** - Migraciones y actualizaciones
6. **6-role.sql** - Configuración de roles y permisos

## 🔧 Comandos Útiles

```bash
# Desarrollo local
docker compose up -d              # Iniciar en segundo plano
docker compose down               # Detener
docker compose logs -f postgres   # Ver logs

# Supabase
npx supabase db push              # Sincronizar cambios
npx supabase db pull              # Traer cambios remotos
npx supabase db reset             # Resetear base de datos local
```

## Proyecto en Supabase

- **Project Ref**: `bdbaagrjlsuibhvbzuwx`
- **Dashboard**: [Supabase Dashboard](https://app.supabase.com/project/bdbaagrjlsuibhvbzuwx)
