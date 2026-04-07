# Informe - Parte A

## 1) Prompt usado con LLM

> Diseña un esquema relacional completo para los siguientes requerimientos (copiados textual del enunciado):
> [sección 3 completa de requerimientos del cliente, sin cambios].
>
> Incluye: tablas, atributos, tipos, PK/FK, restricciones y decisiones de diseño.

## 2) Respuesta resumida del LLM
El LLM propuso tablas para torneos, equipos, jugadores, matches, sponsors y estadísticas. Incluyó claves primarias y varias foráneas.

## 3) Análisis crítico

### Aciertos del esquema LLM
- Separó entidades principales (torneos, equipos, jugadores, matches, sponsors).
- Modeló relaciones N:M (equipos-torneos y sponsors-torneos).
- Incluyó una tabla de estadísticas por jugador y partida.

### Errores / omisiones detectadas
1. **Capitán miembro del equipo**
   - El esquema LLM no aseguraba completamente esta restricción.
   - Solución implementada: trigger `validate_team_captain_membership`.

2. **Cupo máximo de torneo**
   - El LLM sugería validarlo en aplicación.
   - En esta entrega se valida en BD con trigger `enforce_tournament_capacity` para asegurar integridad incluso si cambia la app.

3. **Consistencia de stats por match**
   - Faltaba asegurar que el jugador de `player_match_stats` pertenezca a uno de los dos equipos del match.
   - Se implementó trigger `validate_player_stats_membership`.

4. **Equipos de la partida inscritos al torneo**
   - Se agregó trigger `validate_match_teams_registered`.

### Decisiones de diseño discutibles
- Tipo de fase: `ENUM` vs tabla catálogo. Se eligió `ENUM` por simplicidad y validez en PostgreSQL.
- Jugador en exactamente un equipo: se modeló con `players.team_id NOT NULL`.
- Se definió `email` único para evitar duplicidad y facilitar búsqueda.

## 4) Justificación del esquema final
El esquema final captura correctamente entidades y relaciones, y agrega validaciones de negocio que no se pueden expresar solo con PK/FK/CHECK. Esto alinea el diseño conceptual con la implementación real y evita inconsistencias durante inserciones/actualizaciones.
