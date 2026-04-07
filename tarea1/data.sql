-- IIC2413 Tarea 1 - Datos sintéticos

BEGIN;

INSERT INTO tournaments (name, game_title, start_date, end_date, prize_pool_usd, max_teams) VALUES
('Andes Championship 2026', 'Valorant', '2026-04-01', '2026-04-10', 50000, 8),
('Pacific Clash 2026', 'League of Legends', '2026-05-05', '2026-05-12', 75000, 10),
('Santiago Masters 2026', 'Valorant', '2026-06-01', '2026-06-07', 30000, 6);

INSERT INTO teams (name, created_at) VALUES
('LlamaStrike', '2025-01-15'),
('CondorCore', '2025-02-10'),
('PumaPulse', '2025-03-05'),
('VolcanoFive', '2025-03-11'),
('CryptoFox', '2025-04-01'),
('ByteRiders', '2025-04-20'),
('NebulaUnit', '2025-05-02'),
('DracoStorm', '2025-05-15'),
('PixelRaid', '2025-06-01'),
('TitanGrid', '2025-06-22');

-- 50 jugadores (5 por equipo)
DO $$
DECLARE
  t INTEGER;
  p INTEGER;
  country_list TEXT[] := ARRAY['Chile','Argentina','Peru','Colombia','Brazil'];
BEGIN
  FOR t IN 1..10 LOOP
    FOR p IN 1..5 LOOP
      INSERT INTO players (gamertag, real_name, email, birth_date, country, team_id)
      VALUES (
        format('t%sp%s', t, p),
        format('Player %s-%s', t, p),
        format('player_%s_%s@t1.test', t, p),
        DATE '1998-01-01' + ((t * 19 + p * 7) || ' days')::interval,
        country_list[((t + p - 1) % 5) + 1],
        t
      );
    END LOOP;
  END LOOP;
END $$;

-- capitanes: primer jugador de cada equipo
UPDATE teams t
SET captain_player_id = p.player_id
FROM players p
WHERE p.team_id = t.team_id
  AND p.gamertag = format('t%sp1', t.team_id);

-- registros torneo 1 (lleno con 8 equipos)
INSERT INTO tournament_registrations (tournament_id, team_id) VALUES
(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8);

-- registros torneo 2 (10 equipos)
INSERT INTO tournament_registrations (tournament_id, team_id)
SELECT 2, team_id FROM teams;

-- registros torneo 3 (6 equipos)
INSERT INTO tournament_registrations (tournament_id, team_id) VALUES
(3,1),(3,3),(3,5),(3,7),(3,9),(3,10);

-- sponsors
INSERT INTO sponsors (name, industry) VALUES
('HyperTech', 'technology'),
('PowerDrink', 'beverages'),
('NeoWear', 'clothing'),
('CloudNet', 'technology'),
('ArenaBank', 'finance');

INSERT INTO tournament_sponsors (tournament_id, sponsor_id, contribution_usd) VALUES
(1,1,12000),(1,2,9000),(1,3,7000),(1,4,8000),
(2,1,14000),(2,2,11000),(2,5,10000),
(3,1,6000),(3,3,5000),(3,4,4500),(3,5,4000);

-- Torneo 1 (Valorant) completo: grupos + semifinales + final
-- Grupo A: equipos 1,2,3,4 (6 partidas)
-- Grupo B: equipos 5,6,7,8 (6 partidas)
INSERT INTO matches (tournament_id, team_a_id, team_b_id, scheduled_at, score_a, score_b, phase) VALUES
(1,1,2,'2026-04-01 10:00',13,9,'group_stage'),
(1,1,3,'2026-04-01 13:00',10,13,'group_stage'),
(1,1,4,'2026-04-01 16:00',13,11,'group_stage'),
(1,2,3,'2026-04-02 10:00',13,7,'group_stage'),
(1,2,4,'2026-04-02 13:00',12,12,'group_stage'),
(1,3,4,'2026-04-02 16:00',13,8,'group_stage'),
(1,5,6,'2026-04-03 10:00',13,5,'group_stage'),
(1,5,7,'2026-04-03 13:00',9,13,'group_stage'),
(1,5,8,'2026-04-03 16:00',13,10,'group_stage'),
(1,6,7,'2026-04-04 10:00',11,13,'group_stage'),
(1,6,8,'2026-04-04 13:00',13,9,'group_stage'),
(1,7,8,'2026-04-04 16:00',13,6,'group_stage'),
-- Semifinales: top2 de cada grupo
(1,3,5,'2026-04-06 18:00',13,10,'semifinal'),
(1,1,7,'2026-04-06 21:00',11,13,'semifinal'),
-- Final
(1,3,7,'2026-04-08 20:00',13,11,'final');

-- Algunas partidas para torneo 2 y 3
INSERT INTO matches (tournament_id, team_a_id, team_b_id, scheduled_at, score_a, score_b, phase) VALUES
(2,1,9,'2026-05-05 15:00',2,1,'group_stage'),
(2,2,10,'2026-05-05 18:00',0,2,'group_stage'),
(3,1,3,'2026-06-01 14:00',1,0,'group_stage'),
(3,5,7,'2026-06-01 17:00',0,1,'group_stage');

-- Estadísticas individuales para TODAS las partidas
INSERT INTO player_match_stats (match_id, player_id, kos, restarts, assists)
SELECT
  m.match_id,
  p.player_id,
  ((m.match_id + p.player_id) % 15) + 3 AS kos,
  ((m.match_id + p.player_id) % 8) + 1 AS restarts,
  ((m.match_id * 2 + p.player_id) % 12) + 1 AS assists
FROM matches m
JOIN players p ON p.team_id IN (m.team_a_id, m.team_b_id);

COMMIT;

-- Caso de prueba requerido: intento de inscripción cuando torneo lleno
DO $$
BEGIN
  BEGIN
    INSERT INTO tournament_registrations (tournament_id, team_id) VALUES (1,9);
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected rejection captured: %', SQLERRM;
  END;
END $$;
