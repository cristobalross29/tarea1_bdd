-- IIC2413 Tarea 1 - Torneo de Gaming
-- PostgreSQL 14+

DROP TABLE IF EXISTS player_match_stats CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS tournament_sponsors CASCADE;
DROP TABLE IF EXISTS tournament_registrations CASCADE;
DROP TABLE IF EXISTS sponsors CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS tournaments CASCADE;
DROP TYPE IF EXISTS tournament_phase CASCADE;

CREATE TYPE tournament_phase AS ENUM (
  'group_stage',
  'quarterfinal',
  'semifinal',
  'final'
);

CREATE TABLE tournaments (
  tournament_id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  game_title VARCHAR(120) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  prize_pool_usd NUMERIC(12,2) NOT NULL CHECK (prize_pool_usd >= 0),
  max_teams INTEGER NOT NULL CHECK (max_teams > 1),
  CHECK (end_date >= start_date)
);

CREATE TABLE teams (
  team_id SERIAL PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE,
  created_at DATE NOT NULL DEFAULT CURRENT_DATE,
  captain_player_id INTEGER
);

CREATE TABLE players (
  player_id SERIAL PRIMARY KEY,
  gamertag VARCHAR(50) NOT NULL UNIQUE,
  real_name VARCHAR(120) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  birth_date DATE NOT NULL,
  country VARCHAR(60) NOT NULL,
  team_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT
);

ALTER TABLE teams
  ADD CONSTRAINT fk_teams_captain
  FOREIGN KEY (captain_player_id)
  REFERENCES players(player_id)
  ON DELETE RESTRICT;

CREATE TABLE tournament_registrations (
  tournament_id INTEGER NOT NULL REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
  team_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
  registered_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tournament_id, team_id)
);

CREATE TABLE matches (
  match_id SERIAL PRIMARY KEY,
  tournament_id INTEGER NOT NULL REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
  team_a_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
  team_b_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
  scheduled_at TIMESTAMP NOT NULL,
  score_a INTEGER NOT NULL CHECK (score_a >= 0),
  score_b INTEGER NOT NULL CHECK (score_b >= 0),
  phase tournament_phase NOT NULL,
  CHECK (team_a_id <> team_b_id)
);

CREATE TABLE player_match_stats (
  match_id INTEGER NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
  player_id INTEGER NOT NULL REFERENCES players(player_id) ON DELETE RESTRICT,
  kos INTEGER NOT NULL CHECK (kos >= 0),
  restarts INTEGER NOT NULL CHECK (restarts >= 0),
  assists INTEGER NOT NULL CHECK (assists >= 0),
  PRIMARY KEY (match_id, player_id)
);

CREATE TABLE sponsors (
  sponsor_id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  industry VARCHAR(80) NOT NULL
);

CREATE TABLE tournament_sponsors (
  tournament_id INTEGER NOT NULL REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
  sponsor_id INTEGER NOT NULL REFERENCES sponsors(sponsor_id) ON DELETE CASCADE,
  contribution_usd NUMERIC(12,2) NOT NULL CHECK (contribution_usd > 0),
  PRIMARY KEY (tournament_id, sponsor_id)
);

CREATE INDEX idx_players_team ON players(team_id);
CREATE INDEX idx_matches_tournament ON matches(tournament_id);
CREATE INDEX idx_matches_phase ON matches(phase);
CREATE INDEX idx_stats_player ON player_match_stats(player_id);

-- Restricción: capitán debe pertenecer al mismo equipo
CREATE OR REPLACE FUNCTION validate_team_captain_membership()
RETURNS TRIGGER AS $$
DECLARE
  captain_team_id INTEGER;
BEGIN
  IF NEW.captain_player_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT team_id INTO captain_team_id
  FROM players
  WHERE player_id = NEW.captain_player_id;

  IF captain_team_id IS NULL THEN
    RAISE EXCEPTION 'Captain player % does not exist', NEW.captain_player_id;
  END IF;

  IF captain_team_id <> NEW.team_id THEN
    RAISE EXCEPTION 'Captain player % must belong to team %', NEW.captain_player_id, NEW.team_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_team_captain
BEFORE UPDATE OF captain_player_id ON teams
FOR EACH ROW
EXECUTE FUNCTION validate_team_captain_membership();

-- Restricción: máximo de equipos por torneo
CREATE OR REPLACE FUNCTION enforce_tournament_capacity()
RETURNS TRIGGER AS $$
DECLARE
  max_slots INTEGER;
  current_count INTEGER;
BEGIN
  SELECT max_teams INTO max_slots
  FROM tournaments
  WHERE tournament_id = NEW.tournament_id
  FOR UPDATE;

  SELECT COUNT(*) INTO current_count
  FROM tournament_registrations
  WHERE tournament_id = NEW.tournament_id;

  IF current_count >= max_slots THEN
    RAISE EXCEPTION 'Tournament % is full (% teams max)', NEW.tournament_id, max_slots;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_tournament_capacity
BEFORE INSERT ON tournament_registrations
FOR EACH ROW
EXECUTE FUNCTION enforce_tournament_capacity();

-- Restricción: equipos de la partida deben estar inscritos al torneo
CREATE OR REPLACE FUNCTION validate_match_teams_registered()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tournament_registrations tr
    WHERE tr.tournament_id = NEW.tournament_id AND tr.team_id = NEW.team_a_id
  ) THEN
    RAISE EXCEPTION 'Team A % is not registered in tournament %', NEW.team_a_id, NEW.tournament_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM tournament_registrations tr
    WHERE tr.tournament_id = NEW.tournament_id AND tr.team_id = NEW.team_b_id
  ) THEN
    RAISE EXCEPTION 'Team B % is not registered in tournament %', NEW.team_b_id, NEW.tournament_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_match_teams_registered
BEFORE INSERT OR UPDATE OF tournament_id, team_a_id, team_b_id ON matches
FOR EACH ROW
EXECUTE FUNCTION validate_match_teams_registered();

-- Restricción: stats solo para jugadores que pertenecen a equipos del match
CREATE OR REPLACE FUNCTION validate_player_stats_membership()
RETURNS TRIGGER AS $$
DECLARE
  ta INTEGER;
  tb INTEGER;
  pteam INTEGER;
BEGIN
  SELECT team_a_id, team_b_id INTO ta, tb
  FROM matches
  WHERE match_id = NEW.match_id;

  IF ta IS NULL THEN
    RAISE EXCEPTION 'Match % does not exist', NEW.match_id;
  END IF;

  SELECT team_id INTO pteam
  FROM players
  WHERE player_id = NEW.player_id;

  IF pteam NOT IN (ta, tb) THEN
    RAISE EXCEPTION 'Player % is not part of match teams (% vs %)', NEW.player_id, ta, tb;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_player_stats_membership
BEFORE INSERT OR UPDATE OF match_id, player_id ON player_match_stats
FOR EACH ROW
EXECUTE FUNCTION validate_player_stats_membership();
