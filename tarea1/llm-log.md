# LLM Log

## 1) Cómo usamos LLM (flujo real)
Partimos pidiéndole al LLM una base técnica y un plan de implementación, antes de programar, para ordenar la tarea completa desde el enunciado.

Prompt inicial usado (resumen del que nos funcionó):
```
Quiero que trabajes como arquitecto técnico y planificador de implementación para esta tarea.
Lee completo el PDF del enunciado antes de responder.
No programes todavía.
Propón stack, orden de implementación, diseño de BD, restricciones clave, consultas complejas y plan para la app web.
Prioriza simplicidad, cumplimiento estricto del enunciado y facilidad de defensa.
PostgreSQL 14+, localhost, SQL explícito sin ORM.
Marca ambigüedades y decisiones discutibles.
```

Después de eso, fuimos iterando en conjunto: el LLM nos hizo preguntas de decisiones donde no estábamos seguros, fuimos moldeando el plan hasta dejarlo claro y recién ahí lo ejecutamos.

## 2) En qué partes usamos LLM
- Planificación global (orden de trabajo y puntos de riesgo).
- Revisión de esquema y restricciones de integridad.
- Apoyo en consultas SQL de Parte C (ranking, sponsors, evolución por fase).
- Apoyo visual básico para templates (sin diseño elaborado, solo legibilidad y orden).
- Apoyo puntual para depurar errores complejos que detectamos al probar.

## 3) Qué obtuvimos
- Un plan de trabajo claro y ejecutable de inicio a fin.
- Una base de datos y aplicación web funcionales para el flujo principal.
- Consultas SQL operativas para las funcionalidades pedidas.
- Mejoras de UX básicas (mensajes claros y formularios más usables).

Importante: aunque el plan estaba bien trabajado, al ejecutar y probar igual aparecieron errores. Eso se corrigió con pruebas + ajustes manuales.

## 4) Errores detectados probando casos (y cómo los resolvimos)

### A) Errores simples (detectados en pruebas y corregidos por nosotros)
- Error encontrado: Inscripción aceptaba envío sin torneo/equipo y terminaba en error de BD.
- Cómo se solucionó: Validación de campos requeridos en backend antes del INSERT.

- Error encontrado: Si fallaba validación, el formulario perdía selección previa.
- Cómo se solucionó: Mantener `id_torneo`, `id_equipo` y `grupo` al re-render.

- Error encontrado: No se mostraba ocupación de cupos en la vista de inscripción.
- Cómo se solucionó: Mostrar `inscritos/max` por torneo en el selector.

- Error encontrado: Seeds no permitían demostrar inscripción exitosa fácilmente.
- Cómo se solucionó: Ajustar `data.sql` para dejar un torneo secundario con cupo libre.

### B) Errores más complejos (detectados en pruebas, pedimos consejo al LLM y luego implementamos nosotros)
- Error encontrado: Evolución por fase mezclaba bloques y no quedaba estrictamente en formato enunciado (`grupos` vs `semifinal+final`).
- Cómo se solucionó: Pedimos orientación para la idea SQL y luego implementamos/validamos manualmente la consulta final.

- Error encontrado: Mensajes de inscripción eran inconsistentes cuando todo dependía de excepción SQL.
- Cómo se solucionó: Pedimos alternativas, y aplicamos nosotros pre-chequeos de duplicado y cupo en backend, manteniendo BD como respaldo.

Prompt corto de ejemplo para estos casos:
```
Probamos estos casos y fallan: [caso 1], [caso 2].
No quiero reescribir toda la app.
Propón una corrección mínima, compatible con PostgreSQL y SQL explícito, y explica cómo validar que quedó bien.
```

## 5) Casos donde el LLM se equivocó o no fue útil
- Si el prompt quedaba ambiguo, el LLM asumía cosas no deseadas (por ejemplo, mezclar fases en estadísticas o proponer cambios más grandes de los necesarios).
- En casos borde, tendía a dejar vacíos de validación si no se especificaban explícitamente (duplicados, cupo, estado del formulario tras error).
- En documentación, al inicio propuso formatos que no coincidían con la exigencia exacta de transparencia.

## 6) Conclusión de uso de LLM
- El LLM fue útil como apoyo para plan y para destrabar problemas complejos.
- Los errores se detectaron principalmente al probar casos reales.
- Varios arreglos fueron directos y los implementamos nosotros.
- En los casos complejos, usamos al LLM como asesor, pero la solución final se ajustó y validó manualmente en código y BD.
