# Tarea 1 - IIC2413

## Integrantes
- Gonzalo Molina - 00000000-0
- Integrante 2 - RUT
- Integrante 3 - RUT

## Variables de entorno (defaults)
- DB_HOST=localhost
- DB_PORT=5432
- DB_USER=postgres
- DB_PASSWORD=postgres
- DB_NAME=tarea1

## Levantar en 5 comandos
```bash
createdb tarea1
psql -d tarea1 -f schema.sql && psql -d tarea1 -f data.sql
cd app && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Abrir http://127.0.0.1:5000

Si aparece `FATAL: role "postgres" does not exist`:
```bash
DB_USER=$(whoami) DB_PASSWORD='' python app.py
```
