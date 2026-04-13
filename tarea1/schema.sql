-- Tarea 1 IIC2413 - Esquema basado en diagrama entregado
-- PostgreSQL 14+

DROP TABLE IF EXISTS ESTADISTICA_INDIVIDUAL CASCADE;
DROP TABLE IF EXISTS PARTIDA CASCADE;
DROP TABLE IF EXISTS SPONSOR_TORNEO CASCADE;
DROP TABLE IF EXISTS SPONSOR CASCADE;
DROP TABLE IF EXISTS INSCRIPCION CASCADE;
DROP TABLE IF EXISTS JUGADOR CASCADE;
DROP TABLE IF EXISTS EQUIPO CASCADE;
DROP TABLE IF EXISTS TORNEO CASCADE;

CREATE TABLE TORNEO (
  id_torneo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL UNIQUE,
  videojuego VARCHAR(120) NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  prize_pool_usd NUMERIC(12,2) NOT NULL CHECK (prize_pool_usd >= 0),
  max_equipos INT NOT NULL CHECK (max_equipos > 1),
  CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE EQUIPO (
  id_equipo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  fecha_creacion DATE NOT NULL,
  capitan_gamertag VARCHAR(50)
);

CREATE TABLE JUGADOR (
  gamertag VARCHAR(50) PRIMARY KEY,
  nombre_real VARCHAR(120) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  fecha_nacimiento DATE NOT NULL,
  pais_origen VARCHAR(80) NOT NULL,
  id_equipo BIGINT NOT NULL REFERENCES EQUIPO(id_equipo) ON DELETE RESTRICT
);

ALTER TABLE EQUIPO
  ADD CONSTRAINT fk_equipo_capitan
  FOREIGN KEY (capitan_gamertag)
  REFERENCES JUGADOR(gamertag)
  ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE INSCRIPCION (
  id_torneo BIGINT NOT NULL REFERENCES TORNEO(id_torneo) ON DELETE CASCADE,
  id_equipo BIGINT NOT NULL REFERENCES EQUIPO(id_equipo) ON DELETE RESTRICT,
  fecha_inscripcion TIMESTAMP NOT NULL DEFAULT NOW(),
  grupo CHAR(1),
  PRIMARY KEY (id_torneo, id_equipo),
  CHECK (grupo IS NULL OR grupo IN ('A','B'))
);

CREATE TABLE PARTIDA (
  id_partida BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_torneo BIGINT NOT NULL REFERENCES TORNEO(id_torneo) ON DELETE CASCADE,
  fecha_hora_programada TIMESTAMP NOT NULL,
  fase VARCHAR(20) NOT NULL CHECK (fase IN ('grupos', 'cuartos_final', 'semifinal', 'final')),
  equipo_a_id BIGINT NOT NULL REFERENCES EQUIPO(id_equipo) ON DELETE RESTRICT,
  equipo_b_id BIGINT NOT NULL REFERENCES EQUIPO(id_equipo) ON DELETE RESTRICT,
  puntaje_equipo_a INT NOT NULL CHECK (puntaje_equipo_a >= 0),
  puntaje_equipo_b INT NOT NULL CHECK (puntaje_equipo_b >= 0),
  CHECK (equipo_a_id <> equipo_b_id)
);

CREATE TABLE ESTADISTICA_INDIVIDUAL (
  id_partida BIGINT NOT NULL REFERENCES PARTIDA(id_partida) ON DELETE CASCADE,
  gamertag VARCHAR(50) NOT NULL REFERENCES JUGADOR(gamertag) ON DELETE RESTRICT,
  kos INT NOT NULL CHECK (kos >= 0),
  restarts INT NOT NULL CHECK (restarts >= 0),
  assists INT NOT NULL CHECK (assists >= 0),
  PRIMARY KEY (id_partida, gamertag)
);

CREATE TABLE SPONSOR (
  id_sponsor BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL UNIQUE,
  industria VARCHAR(80) NOT NULL
);

CREATE TABLE SPONSOR_TORNEO (
  id_sponsor BIGINT NOT NULL REFERENCES SPONSOR(id_sponsor) ON DELETE CASCADE,
  id_torneo BIGINT NOT NULL REFERENCES TORNEO(id_torneo) ON DELETE CASCADE,
  monto_usd NUMERIC(12,2) NOT NULL CHECK (monto_usd > 0),
  PRIMARY KEY (id_sponsor, id_torneo)
);

CREATE INDEX idx_jugador_equipo ON JUGADOR(id_equipo);
CREATE INDEX idx_inscripcion_torneo ON INSCRIPCION(id_torneo);
CREATE INDEX idx_partida_torneo ON PARTIDA(id_torneo);
CREATE INDEX idx_partida_fase ON PARTIDA(fase);

-- Regla: capitán debe pertenecer al equipo
CREATE OR REPLACE FUNCTION fn_capitan_en_su_equipo()
RETURNS TRIGGER AS $$
DECLARE
  equipo_capitan BIGINT;
BEGIN
  IF NEW.capitan_gamertag IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT id_equipo INTO equipo_capitan
  FROM JUGADOR
  WHERE gamertag = NEW.capitan_gamertag;

  IF equipo_capitan IS NULL OR equipo_capitan <> NEW.id_equipo THEN
    RAISE EXCEPTION 'El capitán % debe pertenecer al equipo %', NEW.capitan_gamertag, NEW.id_equipo;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_capitan_en_su_equipo
BEFORE INSERT OR UPDATE OF capitan_gamertag ON EQUIPO
FOR EACH ROW EXECUTE FUNCTION fn_capitan_en_su_equipo();

-- Regla: cada equipo debe quedar con capitán al confirmar transacción
CREATE OR REPLACE FUNCTION fn_equipo_capitan_obligatorio()
RETURNS TRIGGER AS $$
DECLARE
  capitan_actual VARCHAR(50);
BEGIN
  SELECT capitan_gamertag
    INTO capitan_actual
  FROM EQUIPO
  WHERE id_equipo = NEW.id_equipo;

  IF capitan_actual IS NULL THEN
    RAISE EXCEPTION 'El equipo % debe tener capitán', NEW.id_equipo;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_equipo_capitan_obligatorio
AFTER INSERT OR UPDATE OF capitan_gamertag ON EQUIPO
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_equipo_capitan_obligatorio();

-- Regla: membresía fija (un jugador no cambia de equipo)
CREATE OR REPLACE FUNCTION fn_jugador_equipo_inmutable()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.id_equipo IS DISTINCT FROM OLD.id_equipo THEN
    RAISE EXCEPTION 'El jugador % no puede cambiar de equipo (% -> %)', OLD.gamertag, OLD.id_equipo, NEW.id_equipo;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_jugador_equipo_inmutable
BEFORE UPDATE OF id_equipo ON JUGADOR
FOR EACH ROW EXECUTE FUNCTION fn_jugador_equipo_inmutable();

-- Regla: no superar cupo de torneo
CREATE OR REPLACE FUNCTION fn_validar_cupo_torneo()
RETURNS TRIGGER AS $$
DECLARE
  maximo INT;
  inscritos INT;
BEGIN
  SELECT max_equipos INTO maximo FROM TORNEO WHERE id_torneo = NEW.id_torneo FOR UPDATE;
  SELECT COUNT(*) INTO inscritos FROM INSCRIPCION WHERE id_torneo = NEW.id_torneo;

  IF inscritos >= maximo THEN
    RAISE EXCEPTION 'Torneo % lleno: cupo máximo % equipos', NEW.id_torneo, maximo;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_cupo_torneo
BEFORE INSERT ON INSCRIPCION
FOR EACH ROW EXECUTE FUNCTION fn_validar_cupo_torneo();

-- Regla: equipos de partida deben estar inscritos en ese torneo
CREATE OR REPLACE FUNCTION fn_partida_equipos_inscritos()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM INSCRIPCION WHERE id_torneo = NEW.id_torneo AND id_equipo = NEW.equipo_a_id) THEN
    RAISE EXCEPTION 'Equipo A % no inscrito en torneo %', NEW.equipo_a_id, NEW.id_torneo;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM INSCRIPCION WHERE id_torneo = NEW.id_torneo AND id_equipo = NEW.equipo_b_id) THEN
    RAISE EXCEPTION 'Equipo B % no inscrito en torneo %', NEW.equipo_b_id, NEW.id_torneo;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_partida_equipos_inscritos
BEFORE INSERT OR UPDATE OF id_torneo, equipo_a_id, equipo_b_id ON PARTIDA
FOR EACH ROW EXECUTE FUNCTION fn_partida_equipos_inscritos();

-- Regla: stats solo de jugadores que juegan esa partida
CREATE OR REPLACE FUNCTION fn_stats_jugador_valido_en_partida()
RETURNS TRIGGER AS $$
DECLARE
  ea BIGINT;
  eb BIGINT;
  eq_jugador BIGINT;
BEGIN
  SELECT equipo_a_id, equipo_b_id INTO ea, eb FROM PARTIDA WHERE id_partida = NEW.id_partida;
  SELECT id_equipo INTO eq_jugador FROM JUGADOR WHERE gamertag = NEW.gamertag;

  IF eq_jugador NOT IN (ea, eb) THEN
    RAISE EXCEPTION 'Jugador % no pertenece a equipos de la partida %', NEW.gamertag, NEW.id_partida;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stats_jugador_valido_en_partida
BEFORE INSERT OR UPDATE OF id_partida, gamertag ON ESTADISTICA_INDIVIDUAL
FOR EACH ROW EXECUTE FUNCTION fn_stats_jugador_valido_en_partida();
