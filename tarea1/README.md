# Tarea 1 - IIC2413

## Integrantes
- Integrante 1 - RUT
- Integrante 2 - RUT
- Integrante 3 - RUT

## Stack y gestor de paquetes
- Backend: Python + Flask
- Base de datos: PostgreSQL 14+
- Gestor de paquetes Python: `pip` (con `requirements.txt`)

## Variables de entorno para BD
Valores por defecto del enunciado:
- `DB_HOST=localhost`
- `DB_PORT=5432`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`
- `DB_NAME=tarea1`

## Levantar proyecto (5 comandos)
Desde la carpeta `tarea1/`:

```bash
createdb tarea1
psql -d tarea1 -f schema.sql && psql -d tarea1 -f data.sql
cd app && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Abrir: [http://127.0.0.1:5000](http://127.0.0.1:5000)

## Validación mínima recomendada
Con la app levantada en entorno virtual (`tarea1/app`):

```bash
python smoke_test.py
```

El script valida:
- Rutas principales (`/torneos`, `/estadisticas`, `/busqueda`, `/sponsors`, `/inscripcion`).
- Inscripción rechazada por torneo lleno.
- Inscripción rechazada por duplicado.
- Inscripción exitosa y persistencia en BD.

## Nota de conexión local
Si tu instalación local no tiene rol `postgres`, ejecuta la app con:

```bash
DB_USER=$(whoami) DB_PASSWORD='' python app.py
```
