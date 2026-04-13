# LLM Log

## Entrada 01
- Error encontrado: El LLM log estaba en formato extenso con secciones no solicitadas.
- Cómo se solucionó: Se reemplazó por un formato breve con entradas que solo incluyen error encontrado y solución aplicada.

## Entrada 02
- Error encontrado: El formulario de inscripción aceptaba envío sin torneo o sin equipo y terminaba en error de base de datos.
- Cómo se solucionó: Se agregó validación previa de campos requeridos con mensaje claro antes de intentar el INSERT.

## Entrada 03
- Error encontrado: La inscripción duplicada dependía de capturar excepción SQL y podía entregar feedback inconsistente.
- Cómo se solucionó: Se agregó pre-chequeo de duplicado en aplicación para responder con mensaje específico antes del INSERT.

## Entrada 04
- Error encontrado: El rechazo por torneo lleno dependía solo del trigger y no siempre entregaba feedback temprano en la app.
- Cómo se solucionó: Se añadió pre-chequeo de cupo en la ruta de inscripción y se mantuvo el trigger como respaldo de integridad.

## Entrada 05
- Error encontrado: El formulario de inscripción no mostraba cupos por torneo y perdía la selección del usuario al fallar una validación.
- Cómo se solucionó: Se actualizó la vista para mostrar inscritos/max y se preservaron torneo, equipo y grupo en re-render de errores.

## Entrada 06
- Error encontrado: Los datos iniciales dejaban todos los torneos completos y no permitían demostrar una inscripción exitosa con seeds limpios.
- Cómo se solucionó: Se liberó un cupo en un torneo secundario de `data.sql` manteniendo el torneo principal 8/8 y el caso de torneo lleno.

## Entrada 07
- Error encontrado: No existía una validación automática mínima de rutas y flujo de inscripción (éxito, duplicado y torneo lleno).
- Cómo se solucionó: Se agregó un smoke test con `Flask test_client` y chequeos SQL para verificar comportamiento end-to-end.

## Entrada 08
- Error encontrado: La evolución por fase mezclaba cuartos de final con semifinal/final en la comparación pedida por el enunciado.
- Cómo se solucionó: Se ajustó la consulta para comparar explícitamente `grupos` vs `eliminacion (semifinal+final)` sin eliminar `cuartos_final` del esquema.

## Entrada 09
- Error encontrado: El README no dejaba una validación mínima automatizada ni una guía de ejecución suficientemente precisa para reproducir el flujo completo.
- Cómo se solucionó: Se actualizó README con stack, variables, 5 comandos de arranque y ejecución del smoke test de verificación.
