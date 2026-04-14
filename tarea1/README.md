# Tarea 1 - IIC2413

## Integrantes
- Gonzalo Molina - 24642746
- Iñaki Guridi - 24642673
- Cristobal Ross - 24645532

## Variables de entorno para BD
Valores por defecto del enunciado:
- `DB_HOST=localhost`
- `DB_PORT=5432`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`
- `DB_NAME=tarea1`

## Levantar proyecto
Desde la carpeta `tarea1/`:

```bash
createdb tarea1
psql -d tarea1 -f schema.sql && psql -d tarea1 -f data.sql
cd app && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Abrir: [http://127.0.0.1:5000](http://127.0.0.1:5000)

## Ejecutar en Windows (PowerShell, Python 3.12)
Desde la carpeta `tarea1/`:

```powershell
createdb tarea1
psql -d tarea1 -f schema.sql; psql -d tarea1 -f data.sql
 cd app; py -3.12 -m venv .venv; .venv\Scripts\Activate.ps1
pip install -r requirements.txt
py app.py
```

Abrir: [http://127.0.0.1:5000](http://127.0.0.1:5000)


## Stack y gestor de paquetes
- Backend: Python + Flask
- Base de datos: PostgreSQL 14+
- Gestor de paquetes Python: `pip` (con `requirements.txt`)
