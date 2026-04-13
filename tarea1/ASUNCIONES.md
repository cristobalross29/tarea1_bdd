# Asunciones del proyecto

## Alcance y criterios
- Se mantiene la estructura existente del proyecto y se priorizan correcciones puntuales sobre reescrituras.
- Se usan consultas SQL explicitas en Flask; no se incorpora ORM.
- No se agregan requerimientos no pedidos por el enunciado.

## Modelo y reglas
- `cuartos_final` se mantiene como fase valida en el esquema como placeholder, aunque el flujo principal del torneo de ejemplo use grupos -> semifinal -> final.
- El control de cupo maximo de torneo se garantiza en base de datos (trigger) y se refuerza con validacion en la aplicacion.
- La membresia de jugador se modela como fija (sin historial de cambios entre equipos).

## Datos de prueba
- Se mantiene al menos un torneo con cupo completo de 8 equipos y bracket completo para demo.
- Se conserva un caso explicito de intento de inscripcion en torneo lleno para validar rechazo.

## Ejecucion
- El flujo soportado/documentado es ejecutar la app desde el directorio `tarea1/app`.
- No se incorpora hardening adicional para contextos de ejecucion no documentados.
