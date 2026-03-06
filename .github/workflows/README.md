# Configuración del Workflow de GitHub Actions

Este workflow sincroniza automáticamente los cambios de la base de datos con tu proyecto de Supabase.

## Secretos Requeridos en GitHub

Para que el workflow funcione correctamente, necesitas configurar los siguientes secretos en tu repositorio de GitHub:

### 1. PROJECT_ID
Tu referencia de proyecto de Supabase: `bdbaagrjlsuibhvbzuwx`

### 2. SUPABASE_ACCESS_TOKEN
Tu token de acceso de Supabase: `sbp_02e3532bde6a2642346cd654df5dc888e6260208`

Para obtener un nuevo token:
1. Ve a [Supabase Dashboard](https://app.supabase.com/)
2. Ve a Account Settings > Access Tokens
3. Genera un nuevo token

## Cómo añadir los secretos en GitHub

1. Ve a tu repositorio en GitHub
2. Haz clic en **Settings** > **Secrets and variables** > **Actions**
3. Haz clic en **New repository secret**
4. Añade cada uno de los secretos mencionados arriba

## Funcionamiento del Workflow

El workflow se ejecuta automáticamente cuando:
- Haces push a la rama `main`
- Y hay cambios en la carpeta `db/`

También puedes ejecutarlo manualmente desde la pestaña **Actions** en GitHub.

## Archivos de Base de Datos

Los archivos en la carpeta `db/` se ejecutan en orden:
1. `1-schema.sql` - Esquema de la base de datos
2. `2-indexes.sql` - Índices
3. `3-seed.sql` - Datos iniciales
4. `4-views.sql` - Vistas
5. `5-migrate.sql` - Migraciones
6. `6-role.sql` - Roles y permisos

Estos archivos se sincronizan con tu proyecto de Supabase mediante `supabase db push`.
