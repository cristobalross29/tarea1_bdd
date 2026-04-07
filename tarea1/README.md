# Tarea 1 - IIC2413 Bases de Datos

## Integrantes
- Gonzalo Molina - 00000000-0
- Integrante 2 - RUT
- Integrante 3 - RUT

## Requisitos
- PostgreSQL 14+
- Python 3.10+

## Variables de entorno (con defaults)
- `DB_HOST` (default: `localhost`)
- `DB_PORT` (default: `5432`)
- `DB_USER` (default: `postgres`)
- `DB_PASSWORD` (default: `postgres`)
- `DB_NAME` (default: `tarea1`)

## Ejecución en máximo 5 comandos
Desde la carpeta `tarea1/`:

```bash
createdb tarea1
psql -d tarea1 -f schema.sql && psql -d tarea1 -f data.sql
cd app && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Luego abrir: http://127.0.0.1:5000

## Estructura
- `informe.pdf`: Parte A (prompt+respuesta LLM y análisis crítico)
- `schema.sql`: creación de tablas, constraints y triggers
- `data.sql`: carga de datos sintéticos y caso de validación de cupo
- `app/`: código de aplicación web
- `llm-log.pdf`: registro de uso de LLMs
