BEGIN;

INSERT INTO TORNEO (nombre, videojuego, fecha_inicio, fecha_fin, prize_pool_usd, max_equipos) VALUES
('Andes Championship 2026', 'Valorant', '2026-04-01', '2026-04-10', 50000, 8),
('Pacific Clash 2026', 'League of Legends', '2026-05-05', '2026-05-14', 80000, 8),
('Southern Rumble 2026', 'Counter-Strike 2', '2026-06-03', '2026-06-12', 65000, 8),
('Patagonia Open 2026', 'Valorant', '2026-07-15', '9999-12-31', 30000, 8);

INSERT INTO EQUIPO (nombre, fecha_creacion) VALUES
('LlamaStrike', '2025-01-15'),('CondorCore', '2025-02-10'),('PumaPulse', '2025-03-05'),('VolcanoFive', '2025-03-11'),
('CryptoFox', '2025-04-01'),('ByteRiders', '2025-04-20'),('NebulaUnit', '2025-05-02'),('DracoStorm', '2025-05-15'),
('PixelRaid', '2025-06-01'),('TitanGrid', '2025-06-22');

DO $$
DECLARE t INT; p INT; paises TEXT[] := ARRAY['Chile','Argentina','Peru','Colombia','Brazil'];
BEGIN
  FOR t IN 1..10 LOOP
    FOR p IN 1..5 LOOP
      INSERT INTO JUGADOR (gamertag, nombre_real, email, fecha_nacimiento, pais_origen, id_equipo)
      VALUES (
        format('t%sp%s', t, p),
        format('Player %s-%s', t, p),
        format('player_%s_%s@t1.cl', t, p),
        DATE '1999-01-01' + ((t*31 + p*13) || ' days')::interval,
        paises[((t+p-1) % 5) + 1],
        t
      );
    END LOOP;
  END LOOP;
END $$;

UPDATE EQUIPO e
SET capitan_gamertag = format('t%sp1', e.id_equipo);

-- 3 torneos completos: 8 inscritos, grupos A/B (4 y 4)
-- 1 torneo incompleto: 5 inscritos, sin partidas
INSERT INTO INSCRIPCION (id_torneo, id_equipo, grupo) VALUES
(1,1,'A'),(1,2,'A'),(1,3,'A'),(1,4,'A'),(1,5,'B'),(1,6,'B'),(1,7,'B'),(1,8,'B'),
(2,1,'A'),(2,2,'A'),(2,5,'A'),(2,6,'A'),(2,7,'B'),(2,8,'B'),(2,9,'B'),(2,10,'B'),
(3,1,'A'),(3,3,'A'),(3,4,'A'),(3,6,'A'),(3,7,'B'),(3,8,'B'),(3,9,'B'),(3,10,'B'),
(4,2,NULL),(4,4,NULL),(4,5,NULL),(4,9,NULL),(4,10,NULL);

INSERT INTO SPONSOR (nombre, industria) VALUES
('HyperTech','tecnologia'),('PowerDrink','bebidas'),('NeoWear','ropa'),('CloudNet','tecnologia'),
('ArenaBank','finanzas'),('GameFuel','bebidas'),('ByteAir','aerolinea');

INSERT INTO SPONSOR_TORNEO (id_sponsor, id_torneo, monto_usd) VALUES
(1,1,12000),(2,1,9000),(3,1,7000),(4,1,6000),
(1,2,13000),(2,2,10000),(5,2,9000),(6,2,5000),
(1,3,11000),(4,3,8000),(5,3,7500),(7,3,4500),
(1,4,6000),(2,4,5000),(6,4,3000);

-- Torneo 1 completo (8 equipos): grupos round-robin + semifinales + final
INSERT INTO PARTIDA (id_torneo, fecha_hora_programada, fase, equipo_a_id, equipo_b_id, puntaje_equipo_a, puntaje_equipo_b) VALUES
(1,'2026-04-01 10:00','grupos',1,2,13,9),
(1,'2026-04-01 13:00','grupos',1,3,13,7),
(1,'2026-04-01 16:00','grupos',1,4,13,11),
(1,'2026-04-02 10:00','grupos',2,3,10,13),
(1,'2026-04-02 13:00','grupos',2,4,13,8),
(1,'2026-04-02 16:00','grupos',3,4,13,6),
(1,'2026-04-03 10:00','grupos',5,6,13,10),
(1,'2026-04-03 13:00','grupos',5,7,9,13),
(1,'2026-04-03 16:00','grupos',5,8,13,8),
(1,'2026-04-04 10:00','grupos',6,7,11,13),
(1,'2026-04-04 13:00','grupos',6,8,13,9),
(1,'2026-04-04 16:00','grupos',7,8,13,6),
(1,'2026-04-06 18:00','semifinal',1,5,13,10),
(1,'2026-04-06 21:00','semifinal',7,3,11,13),
(1,'2026-04-08 20:00','final',1,3,13,11),

-- Torneo 2 completo (8 equipos): grupos round-robin + semifinales + final
(2,'2026-05-05 15:00','grupos',1,2,2,1),
(2,'2026-05-05 18:00','grupos',1,5,2,0),
(2,'2026-05-06 15:00','grupos',1,6,2,1),
(2,'2026-05-06 18:00','grupos',2,5,1,2),
(2,'2026-05-07 15:00','grupos',2,6,0,2),
(2,'2026-05-07 18:00','grupos',5,6,1,2),
(2,'2026-05-08 15:00','grupos',7,8,1,0),
(2,'2026-05-08 18:00','grupos',7,9,2,0),
(2,'2026-05-09 15:00','grupos',7,10,2,1),
(2,'2026-05-09 18:00','grupos',8,9,1,1),
(2,'2026-05-10 15:00','grupos',8,10,0,2),
(2,'2026-05-10 18:00','grupos',9,10,1,2),
(2,'2026-05-12 19:00','semifinal',1,10,1,2),
(2,'2026-05-12 21:30','semifinal',7,6,2,0),
(2,'2026-05-14 20:00','final',10,7,1,3),

-- Torneo 3 completo (8 equipos): grupos round-robin + semifinales + final
(3,'2026-06-03 14:00','grupos',1,3,16,14),
(3,'2026-06-03 17:00','grupos',1,4,12,12),
(3,'2026-06-04 14:00','grupos',1,6,13,16),
(3,'2026-06-04 17:00','grupos',3,4,14,16),
(3,'2026-06-05 14:00','grupos',3,6,9,16),
(3,'2026-06-05 17:00','grupos',4,6,16,12),
(3,'2026-06-06 14:00','grupos',7,8,16,8),
(3,'2026-06-06 17:00','grupos',7,9,14,16),
(3,'2026-06-07 14:00','grupos',7,10,16,12),
(3,'2026-06-07 17:00','grupos',8,9,10,16),
(3,'2026-06-08 14:00','grupos',8,10,16,14),
(3,'2026-06-08 17:00','grupos',9,10,16,13),
(3,'2026-06-10 19:00','semifinal',4,7,16,14),
(3,'2026-06-10 21:30','semifinal',9,6,13,16),
(3,'2026-06-12 20:00','final',4,6,12,16);

INSERT INTO ESTADISTICA_INDIVIDUAL (id_partida, gamertag, kos, restarts, assists)
SELECT p.id_partida,
       j.gamertag,
       ((p.id_partida + length(j.gamertag)) % 15) + 1,
       ((p.id_partida + length(j.gamertag)) % 8) + 1,
       ((p.id_partida * 2 + length(j.gamertag)) % 12) + 1
FROM PARTIDA p
JOIN JUGADOR j ON j.id_equipo IN (p.equipo_a_id, p.equipo_b_id);

COMMIT;

-- Caso requerido: intento de inscripción en torneo lleno
DO $$
BEGIN
  BEGIN
    INSERT INTO INSCRIPCION (id_torneo, id_equipo) VALUES (1,9);
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Validación esperada (torneo lleno): %', SQLERRM;
  END;
END $$;
