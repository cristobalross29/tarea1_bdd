import os
from flask import Flask, render_template, request, redirect, url_for, flash
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)
app.secret_key = "t1-bdd"


def db_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        dbname=os.getenv("DB_NAME", "tarea1"),
    )


@app.route("/")
def home():
    return redirect(url_for("torneos"))


@app.route("/torneos")
def torneos():
    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id_torneo, nombre, videojuego, fecha_inicio, fecha_fin, prize_pool_usd, max_equipos FROM torneo ORDER BY fecha_inicio;")
    rows = cur.fetchall(); cur.close(); conn.close()
    return render_template("torneos.html", torneos=rows)


@app.route("/torneos/<int:id_torneo>")
def torneo_detalle(id_torneo):
    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT * FROM torneo WHERE id_torneo=%s", (id_torneo,)); torneo = cur.fetchone()

    cur.execute("""
    WITH juegos AS (
      SELECT p.id_torneo, p.equipo_a_id id_equipo,
             CASE WHEN p.puntaje_equipo_a > p.puntaje_equipo_b THEN 1 ELSE 0 END g,
             CASE WHEN p.puntaje_equipo_a = p.puntaje_equipo_b THEN 1 ELSE 0 END e,
             CASE WHEN p.puntaje_equipo_a < p.puntaje_equipo_b THEN 1 ELSE 0 END d
      FROM partida p WHERE p.fase='grupos'
      UNION ALL
      SELECT p.id_torneo, p.equipo_b_id,
             CASE WHEN p.puntaje_equipo_b > p.puntaje_equipo_a THEN 1 ELSE 0 END,
             CASE WHEN p.puntaje_equipo_a = p.puntaje_equipo_b THEN 1 ELSE 0 END,
             CASE WHEN p.puntaje_equipo_b < p.puntaje_equipo_a THEN 1 ELSE 0 END
      FROM partida p WHERE p.fase='grupos'
    )
    SELECT e.nombre equipo, COUNT(*) pj, SUM(g) ganadas, SUM(e) empatadas, SUM(d) perdidas,
           SUM(g)*3 + SUM(e) puntos
    FROM juegos j JOIN equipo e ON e.id_equipo=j.id_equipo
    WHERE j.id_torneo=%s
    GROUP BY e.nombre
    ORDER BY puntos DESC, ganadas DESC, equipo;
    """, (id_torneo,))
    tabla = cur.fetchall()

    cur.execute("""
    SELECT p.fecha_hora_programada, p.fase, ea.nombre equipo_a, p.puntaje_equipo_a, p.puntaje_equipo_b, eb.nombre equipo_b
    FROM partida p
    JOIN equipo ea ON ea.id_equipo=p.equipo_a_id
    JOIN equipo eb ON eb.id_equipo=p.equipo_b_id
    WHERE p.id_torneo=%s
    ORDER BY p.fecha_hora_programada;
    """, (id_torneo,))
    partidas = cur.fetchall()

    cur.execute("""
    SELECT e.nombre
    FROM inscripcion i JOIN equipo e ON e.id_equipo=i.id_equipo
    WHERE i.id_torneo=%s ORDER BY e.nombre;
    """, (id_torneo,))
    equipos = cur.fetchall()

    cur.execute("""
    SELECT s.nombre, s.industria, st.monto_usd
    FROM sponsor_torneo st JOIN sponsor s ON s.id_sponsor=st.id_sponsor
    WHERE st.id_torneo=%s ORDER BY st.monto_usd DESC;
    """, (id_torneo,))
    sponsors = cur.fetchall()

    cur.close(); conn.close()
    return render_template("torneo_detalle.html", torneo=torneo, tabla=tabla, partidas=partidas, equipos=equipos, sponsors=sponsors)


@app.route("/estadisticas")
def estadisticas():
    id_torneo = request.args.get("id_torneo", type=int)
    id_equipo = request.args.get("id_equipo", type=int)

    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id_torneo, nombre FROM torneo ORDER BY nombre;")
    torneos = cur.fetchall()

    ranking, equipos, evolucion = [], [], []
    if id_torneo:
        cur.execute("""
        SELECT j.id_equipo, e.nombre
        FROM inscripcion i
        JOIN equipo e ON e.id_equipo=i.id_equipo
        JOIN jugador j ON j.id_equipo=e.id_equipo
        WHERE i.id_torneo=%s
        GROUP BY j.id_equipo, e.nombre
        ORDER BY e.nombre;
        """, (id_torneo,))
        equipos = cur.fetchall()

        cur.execute("""
        SELECT j.gamertag, e.nombre equipo,
               SUM(es.kos) total_kos, SUM(es.restarts) total_restarts, SUM(es.assists) total_assists,
               ROUND(SUM(es.kos)::numeric / NULLIF(SUM(es.restarts),0), 2) ratio,
               COUNT(DISTINCT es.id_partida) partidas
        FROM estadistica_individual es
        JOIN jugador j ON j.gamertag=es.gamertag
        JOIN equipo e ON e.id_equipo=j.id_equipo
        JOIN partida p ON p.id_partida=es.id_partida
        WHERE p.id_torneo=%s
        GROUP BY j.gamertag, e.nombre
        HAVING COUNT(DISTINCT es.id_partida) >= 2
        ORDER BY ratio DESC NULLS LAST, total_kos DESC;
        """, (id_torneo,))
        ranking = cur.fetchall()

    if id_torneo and id_equipo:
        cur.execute("""
        SELECT bloque,
               ROUND(AVG(kos)::numeric,2) avg_kos,
               ROUND(AVG(restarts)::numeric,2) avg_restarts,
               ROUND(AVG(assists)::numeric,2) avg_assists
        FROM (
          SELECT CASE WHEN p.fase='grupos' THEN 'grupos' WHEN p.fase IN ('semifinal','final') THEN 'eliminacion' ELSE 'otro' END bloque,
                 es.kos, es.restarts, es.assists
          FROM estadistica_individual es
          JOIN jugador j ON j.gamertag=es.gamertag
          JOIN partida p ON p.id_partida=es.id_partida
          WHERE p.id_torneo=%s AND j.id_equipo=%s AND p.fase IN ('grupos','semifinal','final')
        ) x
        GROUP BY bloque ORDER BY bloque;
        """, (id_torneo, id_equipo))
        evolucion = cur.fetchall()

    cur.close(); conn.close()
    return render_template("estadisticas.html", torneos=torneos, equipos=equipos, ranking=ranking, evolucion=evolucion, id_torneo=id_torneo, id_equipo=id_equipo)


@app.route("/busqueda")
def busqueda():
    gamertag = request.args.get("gamertag", "").strip()
    pais = request.args.get("pais", "").strip()
    equipo = request.args.get("equipo", "").strip()

    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    jugadores, equipos = [], []

    if gamertag or pais:
        cur.execute("""
        SELECT j.gamertag, j.nombre_real, j.pais_origen, e.nombre equipo
        FROM jugador j JOIN equipo e ON e.id_equipo=j.id_equipo
        WHERE (%s='' OR j.gamertag ILIKE '%%'||%s||'%%')
          AND (%s='' OR j.pais_origen ILIKE '%%'||%s||'%%')
        ORDER BY j.gamertag;
        """, (gamertag, gamertag, pais, pais))
        jugadores = cur.fetchall()

    if equipo:
        cur.execute("""
        SELECT e.nombre, e.fecha_creacion, e.capitan_gamertag, COUNT(j.gamertag) cantidad_jugadores
        FROM equipo e LEFT JOIN jugador j ON j.id_equipo=e.id_equipo
        WHERE e.nombre ILIKE '%%'||%s||'%%'
        GROUP BY e.id_equipo
        ORDER BY e.nombre;
        """, (equipo,))
        equipos = cur.fetchall()

    cur.close(); conn.close()
    return render_template("busqueda.html", jugadores=jugadores, equipos=equipos, gamertag=gamertag, pais=pais, equipo=equipo)


@app.route('/sponsors')
def sponsors():
    videojuego = request.args.get('videojuego', '').strip()
    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT DISTINCT videojuego FROM torneo ORDER BY videojuego;")
    juegos = cur.fetchall()
    rows = []

    if videojuego:
        cur.execute("""
        SELECT s.nombre, s.industria, SUM(st.monto_usd) total_aporte
        FROM sponsor s
        JOIN sponsor_torneo st ON st.id_sponsor=s.id_sponsor
        JOIN torneo t ON t.id_torneo=st.id_torneo
        WHERE t.videojuego=%s
          AND NOT EXISTS (
            SELECT 1 FROM torneo tx
            WHERE tx.videojuego=%s
              AND NOT EXISTS (
                SELECT 1 FROM sponsor_torneo stx
                WHERE stx.id_torneo=tx.id_torneo AND stx.id_sponsor=s.id_sponsor
              )
          )
        GROUP BY s.id_sponsor, s.nombre, s.industria
        ORDER BY total_aporte DESC;
        """, (videojuego, videojuego))
        rows = cur.fetchall()

    cur.close(); conn.close()
    return render_template('sponsors.html', juegos=juegos, rows=rows, videojuego=videojuego)


@app.route('/inscripcion', methods=['GET','POST'])
def inscripcion():
    conn = db_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    if request.method == 'POST':
        id_torneo = request.form.get('id_torneo', type=int)
        id_equipo = request.form.get('id_equipo', type=int)
        grupo = request.form.get('grupo') or None
        try:
            cur.execute("INSERT INTO inscripcion (id_torneo, id_equipo, grupo) VALUES (%s,%s,%s)", (id_torneo, id_equipo, grupo))
            conn.commit()
            flash('Inscripción realizada', 'ok')
            return redirect(url_for('inscripcion'))
        except Exception as e:
            conn.rollback()
            flash(f'Error al inscribir: {e}', 'err')

    cur.execute("SELECT id_torneo, nombre FROM torneo ORDER BY nombre;")
    torneos = cur.fetchall()
    cur.execute("SELECT id_equipo, nombre FROM equipo ORDER BY nombre;")
    equipos = cur.fetchall()
    cur.close(); conn.close()
    return render_template('inscripcion.html', torneos=torneos, equipos=equipos)


if __name__ == '__main__':
    app.run(debug=True)
