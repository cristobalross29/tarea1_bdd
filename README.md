# t1_bdd
Tarea 1 del curso de Base de Datos.

## Ejecutar en Windows (PowerShell)
Desde la raiz del repositorio:

```powershell
cd tarea1
createdb tarea1
psql -d tarea1 -f schema.sql
psql -d tarea1 -f data.sql
cd app
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
py app.py
```

Abrir: [http://127.0.0.1:5000](http://127.0.0.1:5000)

Para mas detalle, ver [README de la app](./tarea1/README.md).
