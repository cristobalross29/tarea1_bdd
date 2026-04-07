# Informe - Parte A

## Prompt usado
Se usó un LLM pidiéndole diseñar un esquema relacional para el enunciado completo de la tarea.

## Comparación crítica
El esquema inicial del LLM cubría entidades principales, pero no aseguraba totalmente reglas de negocio.

## Esquema final adoptado (basado en el esquema solicitado)
Se implementó el esquema entregado:
- TORNEO
- EQUIPO
- JUGADOR
- INSCRIPCION
- PARTIDA
- ESTADISTICA_INDIVIDUAL
- SPONSOR y SPONSOR_TORNEO

## Ajustes aplicados sobre el esquema base
1. Se agregó `puntaje_equipo_b` en PARTIDA (el campo venía truncado en el texto).
2. Se agregaron restricciones y triggers para asegurar:
   - capitán pertenece al equipo,
   - no exceder cupo de torneo,
   - equipos de partida inscritos,
   - stats solo para jugadores de equipos participantes.

Estos cambios preservan el modelo pedido y lo dejan consistente para ejecución real.
