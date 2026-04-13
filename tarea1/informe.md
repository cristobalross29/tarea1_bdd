# Informe - Parte A

## 1) Objetivo
Este informe documenta el uso de un LLM para proponer un esquema relacional para la tarea, su análisis crítico y los ajustes realizados para llegar al diseño final implementado en PostgreSQL 14+.

## 2) Resumen conceptual del dominio
El dominio modela torneos de esports con estas piezas centrales:
- `TORNEO`: metadatos del torneo y cupo máximo.
- `EQUIPO` y `JUGADOR`: jugadores pertenecen a exactamente un equipo (membresía fija).
- `INSCRIPCION`: relación N:M equipo-torneo con grupo opcional (`A`/`B`).
- `PARTIDA`: dos equipos distintos por partido, fase y resultado.
- `ESTADISTICA_INDIVIDUAL`: métricas por jugador y por partida.
- `SPONSOR` y `SPONSOR_TORNEO`: auspicios con monto por torneo.

## 3) Comparación crítica con propuesta inicial del LLM

### 3.1 Cambios estructurales aplicados
1. **Se eliminó `equipo_jugador`**.
   - Propuesta LLM: tabla intermedia para membresía.
   - Diseño final: `JUGADOR.id_equipo` obligatorio.
   - Justificación: el enunciado fija membresía 1 equipo por jugador sin historial. Es más simple y mantiene 3FN.

2. **Se eliminó `match_team`** (tabla intermedia para equipos en partida).
   - Propuesta LLM: modelar equipos de partida en tabla puente.
   - Diseño final: `PARTIDA.equipo_a_id` y `PARTIDA.equipo_b_id`.
   - Justificación: la cardinalidad está fijada en exactamente 2 equipos; columnas directas simplifican consultas y restricciones.

3. **Se corrigió relación redundante de capitán**.
   - Propuesta LLM: diseño con potencial circularidad y validación parcial.
   - Diseño final: `EQUIPO.capitan_gamertag -> JUGADOR(gamertag)` + trigger de pertenencia.
   - Justificación: se evita redundancia y se valida negocio directamente en BD.

4. **`tournament_sponsor` quedó correctamente como relación `SPONSOR_TORNEO`**.
   - Se confirmó que no es entidad independiente de negocio, sino tabla puente N:M con atributo `monto_usd`.

### 3.2 Errores/omisiones del LLM detectados y corregidos
1. **No garantizar “membresía fija” de jugador**.
   - Problema: sin restricción de inmutabilidad, un jugador podía cambiar de equipo.
   - Corrección aplicada: trigger `trg_jugador_equipo_inmutable` en `JUGADOR`.

2. **Validación de capitán incompleta frente a estados transitorios**.
   - Problema: podía persistir equipo sin capitán al cerrar transacción.
   - Corrección aplicada: trigger de restricción diferible `trg_equipo_capitan_obligatorio`.

3. **Fases con nomenclatura no alineada con enunciado**.
   - Problema: se usaba `cuartos` genérico.
   - Corrección aplicada: dominio de fase alineado a `cuartos_final`.

4. **Tabla de posiciones sin separación por grupo**.
   - Problema: el cálculo mezclaba grupos en la vista de torneo.
   - Corrección aplicada: query web ajustada para agrupar y ordenar por `grupo`.

5. **Mensajes de error poco claros en inscripción**.
   - Problema: se mostraba excepción SQL cruda.
   - Corrección aplicada: traducción a mensajes claros para torneo lleno y duplicados.

### 3.3 Decisiones del LLM que sí fueron correctas
- Separar `SPONSOR` y `SPONSOR_TORNEO`.
- Uso de restricciones de dominio (`CHECK` y `UNIQUE`).
- Reconocer que algunas reglas de negocio requieren trigger (por ejemplo, cupo máximo por torneo).

## 4) Restricciones del enunciado y representación final

| Restricción | Implementación final | Tipo |
|---|---|---|
| Gamertag único | `JUGADOR.gamertag PRIMARY KEY` | Declarativa |
| Nombre de equipo único | `EQUIPO.nombre UNIQUE` | Declarativa |
| Jugador pertenece a exactamente 1 equipo | `JUGADOR.id_equipo NOT NULL FK` | Declarativa |
| Membresía fija (no cambia) | Trigger `trg_jugador_equipo_inmutable` | Trigger |
| Capitán pertenece al equipo | Trigger `trg_capitan_en_su_equipo` | Trigger |
| Equipo debe tener capitán | Trigger diferible `trg_equipo_capitan_obligatorio` | Trigger |
| Equipo no puede inscribirse dos veces en torneo | PK `(id_torneo, id_equipo)` en `INSCRIPCION` | Declarativa |
| Cupo máximo por torneo | Trigger `trg_validar_cupo_torneo` | Trigger |
| Partida enfrenta dos equipos distintos | `CHECK (equipo_a_id <> equipo_b_id)` | Declarativa |
| Equipos de partida deben estar inscritos | Trigger `trg_partida_equipos_inscritos` | Trigger |
| Stats por jugador-partida sin duplicar | PK `(id_partida, gamertag)` | Declarativa |
| Stats solo para jugadores participantes | Trigger `trg_stats_jugador_valido_en_partida` | Trigger |
| Sponsors por torneo con monto | `SPONSOR_TORNEO` + `monto_usd` | Declarativa |

## 5) Conclusión crítica
El LLM ayudó a acelerar el diseño inicial, pero dejó varias restricciones clave en estado parcial o ambiguo. El esquema final adoptado se defendió con foco en:
- normalización suficiente para el alcance,
- restricciones de integridad en base de datos (no solo en frontend),
- consultas SQL explícitas y auditables,
- alineación con PostgreSQL 14+ y con el enunciado de la tarea.

---

## Anexo A — Prompt completo usado al LLM

```text
Quiero que actúes como un analista profesional senior y arquitecto de bases de datos relacionales, con criterio académico universitario y enfoque en PostgreSQL.
Necesito que diseñes un esquema relacional a partir de los requerimientos que te voy a pegar. Tu trabajo no debe ser solo “dar tablas”, sino hacer un diseño sólido, justificando cada decisión como lo haría un analista profesional. No quiero una respuesta superficial.
INSTRUCCIONES IMPORTANTES:
1. Usa exclusivamente los requerimientos que te voy a dar.
2. No inventes requerimientos adicionales sin marcarlo explícitamente como supuesto.
3. Si algo es ambiguo, debes:
   - decir por qué es ambiguo,
   - explicitar el supuesto que adoptas,
   - justificar por qué ese supuesto es razonable.
4. Prioriza un diseño correcto, normalizado y defendible en una tarea universitaria de bases de datos.
5. Piensa en PostgreSQL 14+.
6. Debes capturar no solo entidades, sino también restricciones del dominio.
7. Debes distinguir claramente entre:
   - restricciones que sí se pueden imponer directamente con PK, FK, UNIQUE, CHECK, NOT NULL, etc.
   - restricciones que probablemente requerirían lógica adicional, triggers o validación en la aplicación.
8. No uses ORM ni enfoques orientados a objetos; esto es diseño relacional.
9. Tu respuesta debe ser rigurosa, detallada y con lenguaje profesional, pero clara.
FORMATO OBLIGATORIO DE LA RESPUESTA:
### 1) Resumen conceptual del dominio
Explica brevemente cuáles son las entidades principales, relaciones y reglas de negocio importantes.
### 2) Supuestos y ambigüedades detectadas
Haz una lista explícita de todos los puntos ambiguos del enunciado y qué decisión tomaste en cada caso.
### 3) Esquema relacional propuesto
Entrega el esquema en formato estructurado por tabla.
Para cada tabla, incluye:
- nombre de la tabla
- propósito de la tabla
- atributos con tipo de dato sugerido
- clave primaria
- claves foráneas
- restricciones relevantes (UNIQUE, NOT NULL, CHECK, etc.)
Quiero que lo presentes ordenado y limpio.
### 4) Justificación profesional de diseño
Para cada tabla y para cada decisión importante, explica:
- por qué esa tabla existe,
- por qué esos atributos están ahí,
- por qué elegiste esa PK,
- por qué modelaste esa relación de esa manera,
- qué otras alternativas había,
- por qué tu decisión es mejor o más defendible.
No quiero frases genéricas. Quiero razonamiento profesional real.
### 5) Restricciones del enunciado y cómo quedan representadas
Haz una tabla o lista donde tomes cada restricción importante del problema y expliques:
- si quedó bien representada o no,
- en qué parte del esquema aparece,
- si se impone con restricciones declarativas o con lógica adicional.
Ejemplos del tipo de cosas que debes revisar:
- gamertag único
- nombre de equipo único
- un jugador pertenece a exactamente un equipo
- el capitán debe pertenecer al equipo
- un equipo puede inscribirse en muchos torneos
- cada partida enfrenta exactamente dos equipos distintos
- estadísticas individuales por jugador y por partida
- sponsors con monto aportado por torneo
- máximo de equipos por torneo
- fases del torneo
- formato del torneo descrito
### 6) Revisión crítica del propio diseño
Quiero que seas autocrítico.
Indica:
- decisiones discutibles,
- posibles debilidades,
- cosas que podrían modelarse de otra forma,
- qué partes son fáciles de implementar,
- qué partes son difíciles de garantizar solo con el esquema.
### 7) Versión final resumida
Al final, entrega una versión compacta del esquema final, solo con tablas, atributos, PK, FK y restricciones clave, para que sea fácil de comparar con otros diseños.
### 8) Errores comunes que un LLM podría cometer en este problema
Indica al menos 5 errores típicos o trampas de diseño que podrían aparecer en un esquema mal hecho para este caso.
Ahora diseña el esquema a partir de estos requerimientos:

La organización necesita gestionar la siguiente información:
1. Torneos. La organización realiza múltiples torneos. Cada torneo tiene un nombre, el título del video-
juego que se juega, fechas de inicio y fin, y un pozo de premios (prize pool) en USD. Además tiene un
número máximo de equipos por participar.
2. Jugadores. Los jugadores se registran en la plataforma con un gamertag (único), su nombre real,
email, fecha de nacimiento y país de origen.
3. Equipos. Los jugadores forman equipos (de un numero no acotado de jugadores). Cada equipo tiene
un nombre único, una fecha de creación y un capitán. El capitán debe ser miembro del equipo. Un
jugador pertenece a exactamente un equipo (la membresía es fija, no cambia entre torneos).
4. Inscripción a torneos. Los equipos se inscriben en torneos. Cada torneo tiene un número máximo
de equipos que pueden participar. Un equipo puede inscribirse en múltiples torneos.
5. Partidas. Dentro de un torneo se juegan partidas (matches). Cada partida enfrenta a exactamente dos
equipos distintos, tiene una fecha y hora programada, un resultado (puntaje equipo A y puntaje equipo
B) y una fase del torneo. Las fases posibles son: fase de grupos, cuartos de final, semifinal,
final. El formato del torneo es: 8 equipos divididos en 2 grupos de 4, round-robin dentro de cada
grupo, los 2 mejores de cada grupo avanzan a semifinales, luego final.
6. Estadísticas individuales. Para cada partida se registran las estadísticas de cada jugador de los
equipos participantes: KOs, restarts y assists.
7. Sponsors. Empresas pueden auspiciar torneos. De cada sponsor se conoce su nombre, industria (tec-
nología, bebidas, ropa, etc.) y el monto en USD que aporta a cada torneo que auspicia. Un sponsor
puede auspiciar múltiples torneos.
```

## Anexo B — Respuesta completa del LLM (texto original)

```text
1) Resumen conceptual del dominio
El dominio gestiona torneos de esports. Las entidades centrales son torneos, equipos y jugadores. Los jugadores pertenecen a exactamente un equipo (membresía fija). Los equipos se inscriben en torneos (relación N:M con restricción de cupo). Dentro de cada torneo se juegan partidas que enfrentan exactamente dos equipos, organizadas en fases definidas. Por cada partida se registran estadísticas individuales de cada jugador participante. Finalmente, sponsors aportan montos económicos a torneos específicos.
Las reglas de negocio más críticas son: (a) el capitán debe ser miembro del equipo, (b) el cupo máximo del torneo debe respetarse, (c) cada partida involucra exactamente dos equipos distintos, (d) las estadísticas se registran por jugador y por partida, y (e) el monto del sponsor es por torneo, no global.

2) Supuestos y ambigüedades detectadas
#Punto ambiguoDecisión adoptadaJustificaciónS1El enunciado menciona "cuartos de final" en las fases posibles, pero el formato descrito salta de grupos directamente a semifinales (8 → 4 clasificados → semifinal → final).Se incluye cuartos_de_final como valor válido del enum de fases, pero el formato oficial no lo usa. Se conserva para no perder información posible y por flexibilidad.El enunciado lo menciona explícitamente como fase posible; ignorarlo sería un error de diseño.S2"Puntaje equipo A y puntaje equipo B" — no se especifica si el puntaje es entero, puede ser 0, o tiene límites.INTEGER NOT NULL DEFAULT 0, con CHECK >= 0.Puntajes negativos no tienen sentido semántico en un juego.S3El enunciado no especifica si un equipo puede inscribirse dos veces en el mismo torneo.Se impone UNIQUE (torneo_id, equipo_id) en la tabla de inscripciones.Semánticamente absurdo inscribirse dos veces; es una restricción implícita obvia.S4"Nombre real" del jugador — no se especifica si es nombre + apellido o un solo campo.Un solo campo nombre_real VARCHAR(255).Sin más especificación, no hay razón para particionar. Es fácil cambiar luego si se requiere.S5No se especifica si el email del jugador debe ser único.Se agrega UNIQUE en email.Sería inconsistente que dos jugadores compartan email; es un identificador natural de cuenta.S6No se especifica si una partida puede quedar sin resultado (partido no jugado aún).Los campos de puntaje son INTEGER que aceptan NULL, indicando partido pendiente.Permite representar partidas programadas aún no disputadas, lo cual es realista.S7"Fase de grupos" implica que hay dos grupos (A y B). El enunciado no lo modela explícitamente.Se agrega un atributo grupo CHAR(1) en la tabla de inscripciones (valores 'A' o 'B').Sin saber a qué grupo pertenece cada equipo, no se puede reconstruir la tabla de posiciones por grupo. Supuesto necesario para que el sistema sea funcional.S8No se especifica si los sponsors tienen identificador propio o solo nombre.Se usa una PK surrogate sponsor_id SERIAL.Permite que dos empresas con nombre similar coexistan sin colisión accidental; nombre solo como UNIQUE.S9La restricción de "máximo de equipos" debe evaluarse al momento de inscripción. No queda claro si es declarativa o procedimental.Se almacena max_equipos en la tabla torneo; la validación se delega a lógica de aplicación o trigger.No existe en SQL estándar una restricción declarativa que cuente filas de otra tabla condicionalmente. Se documenta explícitamente.S10No se dice si un jugador puede tener estadísticas en una partida aunque su equipo no esté inscrito (error de datos).Se asume integridad referencial completa: las estadísticas solo pueden existir si el jugador pertenece a un equipo que participó en esa partida. Validación en aplicación.El esquema no puede imponer fácilmente esta restricción sin un trigger.

3) Esquema relacional propuesto

Tabla: torneo
Propósito: Almacena los torneos organizados por la institución.
AtributoTipoRestriccionestorneo_idSERIALPKnombreVARCHAR(255)NOT NULLvideojuegoVARCHAR(255)NOT NULLfecha_inicioDATENOT NULLfecha_finDATENOT NULLprize_pool_usdNUMERIC(12,2)NOT NULL, CHECK > 0max_equiposINTEGERNOT NULL, CHECK > 0
Restricciones adicionales:

CHECK (fecha_fin >= fecha_inicio)


Tabla: jugador
Propósito: Registra a los jugadores de la plataforma.
AtributoTipoRestriccionesjugador_idSERIALPKgamertagVARCHAR(100)NOT NULL, UNIQUEnombre_realVARCHAR(255)NOT NULLemailVARCHAR(255)NOT NULL, UNIQUEfecha_nacimientoDATENOT NULLpais_origenVARCHAR(100)NOT NULL

Tabla: equipo
Propósito: Representa los equipos formados por jugadores.
AtributoTipoRestriccionesequipo_idSERIALPKnombreVARCHAR(255)NOT NULL, UNIQUEfecha_creacionDATENOT NULLcapitan_idINTEGERNOT NULL, FK → jugador(jugador_id)
Nota sobre la restricción del capitán: La restricción "el capitán debe ser miembro del equipo" no puede resolverse completamente con FK aquí, porque introduce una dependencia circular entre equipo y equipo_jugador. Se documenta en la sección 5.

Tabla: equipo_jugador
Propósito: Representa la membresía fija de un jugador en exactamente un equipo. Es la tabla que concreta la relación 1:N entre equipos y jugadores.
AtributoTipoRestriccionesjugador_idINTEGERPK, FK → jugador(jugador_id)equipo_idINTEGERNOT NULL, FK → equipo(equipo_id)
Notas:

jugador_id es la PK completa: garantiza que un jugador pertenezca a exactamente un equipo.
No se necesita surrogate key aquí; la relación es 1:1 desde el punto de vista del jugador.


Tabla: inscripcion
Propósito: Registra qué equipos están inscritos en qué torneos, incluyendo la asignación de grupo en la fase de grupos.
AtributoTipoRestriccionesinscripcion_idSERIALPKtorneo_idINTEGERNOT NULL, FK → torneo(torneo_id)equipo_idINTEGERNOT NULL, FK → equipo(equipo_id)grupoCHAR(1)CHECK IN ('A', 'B'), puede ser NULL si aún no se asignafecha_inscripcionTIMESTAMPNOT NULL, DEFAULT NOW()
Restricciones adicionales:

UNIQUE (torneo_id, equipo_id) — un equipo no puede inscribirse dos veces en el mismo torneo.
La validación de max_equipos requiere lógica en aplicación o trigger (ver sección 5).


Tabla: partida
Propósito: Registra cada match jugado dentro de un torneo, con sus dos equipos, resultado y fase.
AtributoTipoRestriccionespartida_idSERIALPKtorneo_idINTEGERNOT NULL, FK → torneo(torneo_id)equipo_a_idINTEGERNOT NULL, FK → equipo(equipo_id)equipo_b_idINTEGERNOT NULL, FK → equipo(equipo_id)fecha_horaTIMESTAMPNOT NULLpuntaje_aINTEGERCHECK >= 0, puede ser NULL (partido pendiente)puntaje_bINTEGERCHECK >= 0, puede ser NULL (partido pendiente)fasefase_torneo (enum)NOT NULL
Tipo enumerado:
sqlCREATE TYPE fase_torneo AS ENUM (
  'fase_de_grupos',
  'cuartos_de_final',
  'semifinal',
  'final'
);
Restricciones adicionales:

CHECK (equipo_a_id <> equipo_b_id) — los dos equipos deben ser distintos.
CHECK ((puntaje_a IS NULL AND puntaje_b IS NULL) OR (puntaje_a IS NOT NULL AND puntaje_b IS NOT NULL)) — o ambos puntajes existen o ninguno (partido jugado completo o pendiente).
Restricción de que ambos equipos deben estar inscritos en ese torneo: requiere trigger o validación en aplicación.


Tabla: estadistica_jugador
Propósito: Almacena las estadísticas individuales de cada jugador en cada partida.
AtributoTipoRestriccionesestadistica_idSERIALPKpartida_idINTEGERNOT NULL, FK → partida(partida_id)jugador_idINTEGERNOT NULL, FK → jugador(jugador_id)kosINTEGERNOT NULL, DEFAULT 0, CHECK >= 0restartsINTEGERNOT NULL, DEFAULT 0, CHECK >= 0assistsINTEGERNOT NULL, DEFAULT 0, CHECK >= 0
Restricciones adicionales:

UNIQUE (partida_id, jugador_id) — un jugador tiene exactamente un registro de estadísticas por partida.


Tabla: sponsor
Propósito: Almacena los datos de cada empresa patrocinadora.
AtributoTipoRestriccionessponsor_idSERIALPKnombreVARCHAR(255)NOT NULL, UNIQUEindustriaVARCHAR(100)NOT NULL

Tabla: sponsor_torneo
Propósito: Relaciona sponsors con torneos y registra el monto aportado por cada sponsor a cada torneo.
AtributoTipoRestriccionessponsor_idINTEGERPK (compuesta), FK → sponsor(sponsor_id)torneo_idINTEGERPK (compuesta), FK → torneo(torneo_id)monto_usdNUMERIC(12,2)NOT NULL, CHECK > 0
PK compuesta: (sponsor_id, torneo_id) — un sponsor aporta un único monto por torneo.

4) Justificación profesional de diseño
torneo: Existe como entidad independiente porque los torneos son el objeto central del sistema. prize_pool_usd es NUMERIC(12,2) y no FLOAT porque los montos monetarios nunca deben almacenarse con punto flotante (riesgo de errores de redondeo). max_equipos está en la tabla porque es un atributo propio del torneo, no derivable. La PK es surrogate (SERIAL) porque el nombre del torneo podría repetirse en el tiempo.
jugador: Entidad independiente con PK surrogate. gamertag es UNIQUE NOT NULL porque el enunciado lo define explícitamente como identificador único en la plataforma. Se podría haber usado gamertag directamente como PK natural, pero una clave surrogate es más robusta si el gamertag eventualmente puede cambiar (aunque el enunciado no lo contempla). email con UNIQUE es un supuesto razonable documentado.
equipo + equipo_jugador: Se separan deliberadamente. equipo describe las propiedades del equipo; equipo_jugador modela la membresía. Poner equipo_id directamente en jugador habría sido una opción, pero es menos flexible y semánticamente más acoplada. Al hacer jugador_id la PK de equipo_jugador, se garantiza automáticamente que un jugador pertenezca a exactamente un equipo — es una restricción elegante sin necesidad de triggers.
El capitan_id en equipo referencia a jugador, no a equipo_jugador, para evitar complejidad de FK compuesta. La restricción adicional (que el capitán sea miembro) se discute en la sección 5.
inscripcion: Es una relación N:M entre equipo y torneo. Se añade grupo como atributo propio de la inscripción porque la asignación de grupo (A o B) es una propiedad de esa participación específica, no del equipo ni del torneo por separado. fecha_inscripcion agrega trazabilidad sin costo.
partida: Se usa un enum de PostgreSQL para fase en lugar de un VARCHAR libre, porque los valores son exactamente conocidos y fijos. Esto impone validación a nivel de base de datos sin overhead. equipo_a_id y equipo_b_id son dos FKs separadas al mismo equipo: alternativa clásica a una tabla de "equipo_partida". La alternativa sería una tabla equipo_partida(partida_id, equipo_id, rol) que permitiría N equipos por partida, pero el enunciado dice explícitamente exactamente dos, y la solución con dos columnas es más simple, directa y consultable. El CHECK (equipo_a_id <> equipo_b_id) es la restricción declarativa más importante de esta tabla.
estadistica_jugador: Existe como tabla separada, no como columnas adicionales en equipo_jugador o jugador, porque las estadísticas son por (jugador × partida), lo cual es una relación N:M con atributos. El UNIQUE (partida_id, jugador_id) garantiza que no haya registros duplicados para la misma combinación.
sponsor + sponsor_torneo: Se normalizan correctamente. El monto está en sponsor_torneo porque es un atributo de la relación (varía por torneo), no del sponsor en sí. Colocarlo en sponsor habría sido un error de normalización grave.

5) Restricciones del enunciado y cómo quedan representadas
Restricción¿Representada?DóndeTipo de implementaciónGamertag único✅jugador.gamertag UNIQUEDeclarativa (DDL)Email único (supuesto)✅jugador.email UNIQUEDeclarativa (DDL)Nombre de equipo único✅equipo.nombre UNIQUEDeclarativa (DDL)Un jugador pertenece a exactamente un equipo✅equipo_jugador.jugador_id es PKDeclarativa (PK)El capitán debe pertenecer al equipo⚠️ Parcialequipo.capitan_id FK → jugador existe, pero no verifica membresíaRequiere trigger o validación en aplicaciónUn equipo puede inscribirse en múltiples torneos✅Tabla inscripcion N:MDeclarativa (modelo)Un equipo no se inscribe dos veces en el mismo torneo✅UNIQUE (torneo_id, equipo_id) en inscripcionDeclarativa (DDL)Máximo de equipos por torneo⚠️ Parcialtorneo.max_equipos almacenadoRequiere trigger o validación en aplicación al insertar en inscripcionCada partida enfrenta exactamente dos equipos distintos✅equipo_a_id, equipo_b_id + CHECK (a <> b)Declarativa (CHECK)Ambos equipos de una partida deben estar inscritos en ese torneo⚠️ ParcialFKs individuales existenRequiere trigger o validación en aplicaciónResultado con ambos puntajes o ninguno✅CHECK sobre nulidad simultánea de puntajesDeclarativa (CHECK)Estadísticas individuales por jugador y por partida✅estadistica_jugador con UNIQUE(partida_id, jugador_id)Declarativa (DDL)KOs, restarts, assists ≥ 0✅CHECK >= 0 en cada columnaDeclarativa (CHECK)Sponsors con monto aportado por torneo✅sponsor_torneo.monto_usdDeclarativa (modelo)Monto del sponsor > 0✅CHECK > 0Declarativa (CHECK)Fases válidas del torneo✅Tipo fase_torneo ENUMDeclarativa (tipo)Formato: 8 equipos, 2 grupos, round-robin, etc.⚠️ Parcialinscripcion.grupo, max_equipos = 8 convencionalLógica de negocio en aplicación; el esquema no impone el formato completo

6) Revisión crítica del propio diseño
Decisiones discutibles:

La columna grupo en inscripcion: Es un supuesto mío. El enunciado no pide explícitamente almacenar el grupo de cada equipo. Sin embargo, sin este dato, no es posible construir la tabla de posiciones de fase de grupos (que sí se pide en la Parte C). Es un supuesto necesario y bien justificado.
capitan_id en equipo: La dependencia circular con equipo_jugador hace que la restricción del capitán-miembro sea difícil de imponer declarativamente. Una alternativa sería agregar un flag es_capitan BOOLEAN en equipo_jugador, eliminando la columna capitan_id en equipo. Eso resolvería la circularidad pero complicaría las consultas de "dame el capitán del equipo X". La solución elegida es más práctica para consultas.
PK de equipo_jugador: Usar jugador_id como PK única es elegante, pero implícitamente hace la tabla 1:1 desde el lado del jugador. Si en el futuro se quisiera permitir cambio de equipo con historial, habría que rehacer esta tabla. Sin embargo, el enunciado dice explícitamente que la membresía es fija, así que esta elección es correcta y defenderle en clase es sencillo.
Surrogate key en inscripcion: Se podría usar (torneo_id, equipo_id) como PK compuesta en lugar de inscripcion_id SERIAL. Ambas son válidas. La surrogate facilita referencias desde otras tablas si se necesita en el futuro.

Partes difíciles de garantizar solo con el esquema:

Que el capitán sea miembro del equipo.
Que el torneo no supere max_equipos al inscribir.
Que los equipos de una partida estén inscritos en ese torneo.
Que el número de partidas siga el formato round-robin correctamente.

Partes fáciles:

Unicidad de gamertag, nombre de equipo, email.
Que un jugador esté en un solo equipo.
Que los dos equipos de una partida sean distintos.
El esquema monetario (NUMERIC evita errores de flotante).


7) Versión final resumida
torneo(torneo_id PK, nombre NN, videojuego NN, fecha_inicio NN,
       fecha_fin NN, prize_pool_usd NN CHECK>0,
       max_equipos NN CHECK>0,
       CHECK fecha_fin >= fecha_inicio)

jugador(jugador_id PK, gamertag NN UNIQUE, nombre_real NN,
        email NN UNIQUE, fecha_nacimiento NN, pais_origen NN)

equipo(equipo_id PK, nombre NN UNIQUE, fecha_creacion NN,
       capitan_id NN FK→jugador)

equipo_jugador(jugador_id PK FK→jugador,
               equipo_id NN FK→equipo)

inscripcion(inscripcion_id PK,
            torneo_id NN FK→torneo,
            equipo_id NN FK→equipo,
            grupo CHECK IN ('A','B'),
            fecha_inscripcion NN DEFAULT NOW(),
            UNIQUE(torneo_id, equipo_id))

partida(partida_id PK,
        torneo_id NN FK→torneo,
        equipo_a_id NN FK→equipo,
        equipo_b_id NN FK→equipo,
        fecha_hora NN,
        puntaje_a CHECK>=0,  -- NULL = pendiente
        puntaje_b CHECK>=0,
        fase fase_torneo NN,
        CHECK equipo_a_id <> equipo_b_id,
        CHECK (puntaje_a IS NULL) = (puntaje_b IS NULL))

estadistica_jugador(estadistica_id PK,
                    partida_id NN FK→partida,
                    jugador_id NN FK→jugador,
                    kos NN DEFAULT 0 CHECK>=0,
                    restarts NN DEFAULT 0 CHECK>=0,
                    assists NN DEFAULT 0 CHECK>=0,
                    UNIQUE(partida_id, jugador_id))

sponsor(sponsor_id PK, nombre NN UNIQUE, industria NN)

sponsor_torneo(sponsor_id PK FK→sponsor,
               torneo_id PK FK→torneo,
               monto_usd NN CHECK>0)

8) Errores comunes que un LLM podría cometer en este problema

Poner el monto del sponsor directamente en la tabla sponsor: Error de normalización grave. El monto varía por torneo, no es un atributo fijo del sponsor. Un LLM que no analice la cardinalidad de la relación fácilmente coloca monto_usd en sponsor.
Modelar la membresía del jugador como un campo equipo_id en la tabla jugador: Técnicamente funciona para imponer la pertenencia a un único equipo, pero rompe la separación limpia entre entidad y relación, y hace más difícil razonar sobre la estructura. Un LLM puede hacer esto "por simplicidad" sin pensar en la normalización.
Olvidar el CHECK (equipo_a_id <> equipo_b_id) en partida: Sin esta restricción, el esquema permite que un equipo juegue contra sí mismo. Es una regla de negocio fundamental que pasa inadvertida.
Usar FLOAT o DECIMAL sin precisión para montos monetarios: Un LLM podría usar FLOAT para prize_pool_usd o monto_usd, introduciendo errores de punto flotante. Lo correcto es NUMERIC(12,2).
No modelar las estadísticas como tabla separada: Un LLM podría añadir columnas kos, restarts, assists directamente en equipo_jugador o jugador, perdiendo la dimensión de "por partida". Las estadísticas son por (jugador × partida), no por jugador en general.
No imponer UNIQUE (partida_id, jugador_id) en estadistica_jugador: Sin esta restricción, nada impide insertar dos filas de estadísticas para el mismo jugador en la misma partida, corrompiendo los datos silenciosamente.
Modelar las fases como VARCHAR libre sin restricción: Usar texto libre permite insertar valores como 'final', 'Final', 'FINAL', 'finall' sin error. El uso de un ENUM en PostgreSQL o al menos un CHECK con valores fijos es esencial para integridad de dominio.
```
