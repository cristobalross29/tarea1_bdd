# LLM Log (máx. 2 páginas)

## Herramientas LLM utilizadas
- ChatGPT (apoyo en diseño SQL, validaciones y estructura de app)

## Uso por parte de la tarea
1. **Parte A**
   - Generación inicial de esquema candidato.
   - Apoyo para identificar restricciones difíciles (capitán miembro, cupos, división relacional).

2. **Parte B**
   - Apoyo en redacción de triggers y diseño de datos sintéticos.
   - Verificación de edge cases (`NULLIF` para evitar división por cero).

3. **Parte C**
   - Apoyo para formular consultas SQL explícitas por cada página.
   - Revisión de consultas para sponsors que auspician todos los torneos de un juego.

## Prompts útiles
- "Propón un esquema PostgreSQL para torneo esports incluyendo constraints y triggers para reglas de negocio".
- "Escribe consulta SQL para sponsors que auspiciaron todos los torneos de un juego".
- "Consulta para ranking de KOs/restarts con mínimo de partidas y evitando división por cero".

## Errores/no-utilidad del LLM detectados
- En iteraciones iniciales omitió validación de cupo en nivel BD.
- Sugirió una versión de query de sponsors con `HAVING COUNT(*)`, correcta solo bajo supuestos más estrictos.
- No siempre consideró consistencia entre stats y equipos participantes del match.

## Conclusión
El LLM aceleró el desarrollo, pero fue necesario corregir y validar manualmente restricciones y consultas para asegurar cumplimiento completo del enunciado y preparación para defensa oral.
