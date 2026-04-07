import os
from flask import Flask, render_template, request, redirect, url_for, flash
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)
app.secret_key = "t1-bdd-secret"


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        dbname=os.getenv("DB_NAME", "tarea1"),
    )


@app.route("/")
def home():
    return redirect(url_for("tournaments"))


@app.route("/tournaments")
def tournaments():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        """
        SELECT tournament_id, name, game_title, start_date, end_date, prize_pool_usd, max_teams
        FROM tournaments
        ORDER BY start_date;
        """
    )
    data = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("tournaments.html", tournaments=data)


@app.route("/tournaments/<int:tournament_id>")
def tournament_detail(tournament_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute(
        """
        SELECT tournament_id, name, game_title, start_date, end_date, prize_pool_usd, max_teams
        FROM tournaments
        WHERE tournament_id = %s;
        """,
        (tournament_id,),
    )
    tournament = cur.fetchone()

    cur.execute(
        """
        WITH team_matches AS (
          SELECT m.tournament_id, m.team_a_id AS team_id,
                 CASE WHEN m.score_a > m.score_b THEN 1 ELSE 0 END AS wins,
                 CASE WHEN m.score_a = m.score_b THEN 1 ELSE 0 END AS draws,
                 CASE WHEN m.score_a < m.score_b THEN 1 ELSE 0 END AS losses
          FROM matches m
          WHERE m.phase = 'group_stage'
          UNION ALL
          SELECT m.tournament_id, m.team_b_id AS team_id,
                 CASE WHEN m.score_b > m.score_a THEN 1 ELSE 0 END,
                 CASE WHEN m.score_a = m.score_b THEN 1 ELSE 0 END,
                 CASE WHEN m.score_b < m.score_a THEN 1 ELSE 0 END
          FROM matches m
          WHERE m.phase = 'group_stage'
        )
        SELECT t.name AS team_name,
               COUNT(*) AS played,
               SUM(tm.wins) AS wins,
               SUM(tm.draws) AS draws,
               SUM(tm.losses) AS losses,
               (SUM(tm.wins) * 3 + SUM(tm.draws)) AS points
        FROM team_matches tm
        JOIN teams t ON t.team_id = tm.team_id
        WHERE tm.tournament_id = %s
        GROUP BY t.name
        ORDER BY points DESC, wins DESC, team_name;
        """,
        (tournament_id,),
    )
    standings = cur.fetchall()

    cur.execute(
        """
        SELECT m.match_id, m.scheduled_at, m.phase,
               ta.name AS team_a, tb.name AS team_b,
               m.score_a, m.score_b
        FROM matches m
        JOIN teams ta ON ta.team_id = m.team_a_id
        JOIN teams tb ON tb.team_id = m.team_b_id
        WHERE m.tournament_id = %s
        ORDER BY m.scheduled_at;
        """,
        (tournament_id,),
    )
    matches = cur.fetchall()

    cur.execute(
        """
        SELECT te.name
        FROM tournament_registrations tr
        JOIN teams te ON te.team_id = tr.team_id
        WHERE tr.tournament_id = %s
        ORDER BY te.name;
        """,
        (tournament_id,),
    )
    teams = cur.fetchall()

    cur.execute(
        """
        SELECT s.name, s.industry, ts.contribution_usd
        FROM tournament_sponsors ts
        JOIN sponsors s ON s.sponsor_id = ts.sponsor_id
        WHERE ts.tournament_id = %s
        ORDER BY ts.contribution_usd DESC;
        """,
        (tournament_id,),
    )
    sponsors = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "tournament_detail.html",
        tournament=tournament,
        standings=standings,
        matches=matches,
        teams=teams,
        sponsors=sponsors,
    )


@app.route("/stats")
def stats_page():
    selected_tournament = request.args.get("tournament_id", type=int)
    selected_team = request.args.get("team_id", type=int)

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT tournament_id, name FROM tournaments ORDER BY name;")
    tournaments = cur.fetchall()

    ranking = []
    team_stats = []
    teams = []

    if selected_tournament:
        cur.execute(
            """
            SELECT p.team_id, t.name
            FROM tournament_registrations tr
            JOIN teams t ON t.team_id = tr.team_id
            JOIN players p ON p.team_id = t.team_id
            WHERE tr.tournament_id = %s
            GROUP BY p.team_id, t.name
            ORDER BY t.name;
            """,
            (selected_tournament,),
        )
        teams = cur.fetchall()

        cur.execute(
            """
            SELECT p.gamertag,
                   t.name AS team,
                   SUM(s.kos) AS total_kos,
                   SUM(s.restarts) AS total_restarts,
                   SUM(s.assists) AS total_assists,
                   ROUND(SUM(s.kos)::numeric / NULLIF(SUM(s.restarts), 0), 2) AS ko_restart_ratio,
                   COUNT(DISTINCT s.match_id) AS matches_played
            FROM player_match_stats s
            JOIN players p ON p.player_id = s.player_id
            JOIN teams t ON t.team_id = p.team_id
            JOIN matches m ON m.match_id = s.match_id
            WHERE m.tournament_id = %s
            GROUP BY p.player_id, p.gamertag, t.name
            HAVING COUNT(DISTINCT s.match_id) >= 2
            ORDER BY ko_restart_ratio DESC NULLS LAST, total_kos DESC;
            """,
            (selected_tournament,),
        )
        ranking = cur.fetchall()

    if selected_tournament and selected_team:
        cur.execute(
            """
            SELECT phase_bucket,
                   ROUND(AVG(kos)::numeric, 2) AS avg_kos,
                   ROUND(AVG(restarts)::numeric, 2) AS avg_restarts,
                   ROUND(AVG(assists)::numeric, 2) AS avg_assists
            FROM (
                SELECT CASE
                         WHEN m.phase = 'group_stage' THEN 'group_stage'
                         WHEN m.phase IN ('semifinal', 'final') THEN 'knockout'
                         ELSE 'other'
                       END AS phase_bucket,
                       s.kos,
                       s.restarts,
                       s.assists
                FROM player_match_stats s
                JOIN players p ON p.player_id = s.player_id
                JOIN matches m ON m.match_id = s.match_id
                WHERE m.tournament_id = %s
                  AND p.team_id = %s
                  AND m.phase IN ('group_stage', 'semifinal', 'final')
            ) q
            GROUP BY phase_bucket
            ORDER BY phase_bucket;
            """,
            (selected_tournament, selected_team),
        )
        team_stats = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "stats.html",
        tournaments=tournaments,
        teams=teams,
        ranking=ranking,
        team_stats=team_stats,
        selected_tournament=selected_tournament,
        selected_team=selected_team,
    )


@app.route("/search")
def search_page():
    player_q = request.args.get("player_q", "").strip()
    country_q = request.args.get("country_q", "").strip()
    team_q = request.args.get("team_q", "").strip()

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    players = []
    teams = []

    if player_q or country_q:
        cur.execute(
            """
            SELECT p.gamertag, p.real_name, p.country, t.name AS team_name
            FROM players p
            JOIN teams t ON t.team_id = p.team_id
            WHERE (%s = '' OR p.gamertag ILIKE '%%' || %s || '%%')
              AND (%s = '' OR p.country ILIKE '%%' || %s || '%%')
            ORDER BY p.gamertag;
            """,
            (player_q, player_q, country_q, country_q),
        )
        players = cur.fetchall()

    if team_q:
        cur.execute(
            """
            SELECT t.name,
                   t.created_at,
                   cp.gamertag AS captain,
                   COUNT(p.player_id) AS roster_size
            FROM teams t
            LEFT JOIN players cp ON cp.player_id = t.captain_player_id
            LEFT JOIN players p ON p.team_id = t.team_id
            WHERE t.name ILIKE '%%' || %s || '%%'
            GROUP BY t.team_id, cp.gamertag
            ORDER BY t.name;
            """,
            (team_q,),
        )
        teams = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "search.html",
        players=players,
        teams=teams,
        player_q=player_q,
        country_q=country_q,
        team_q=team_q,
    )


@app.route("/sponsors")
def sponsors_page():
    selected_game = request.args.get("game_title", "").strip()

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT DISTINCT game_title FROM tournaments ORDER BY game_title;")
    games = cur.fetchall()

    sponsors = []
    if selected_game:
        cur.execute(
            """
            SELECT s.name, s.industry, SUM(ts.contribution_usd) AS total_contribution_usd
            FROM sponsors s
            JOIN tournament_sponsors ts ON ts.sponsor_id = s.sponsor_id
            JOIN tournaments t ON t.tournament_id = ts.tournament_id
            WHERE t.game_title = %s
              AND NOT EXISTS (
                SELECT 1
                FROM tournaments tx
                WHERE tx.game_title = %s
                  AND NOT EXISTS (
                    SELECT 1
                    FROM tournament_sponsors tsx
                    WHERE tsx.tournament_id = tx.tournament_id
                      AND tsx.sponsor_id = s.sponsor_id
                  )
              )
            GROUP BY s.sponsor_id, s.name, s.industry
            ORDER BY total_contribution_usd DESC;
            """,
            (selected_game, selected_game),
        )
        sponsors = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "sponsors.html",
        games=games,
        selected_game=selected_game,
        sponsors=sponsors,
    )


@app.route("/register", methods=["GET", "POST"])
def register_team():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    if request.method == "POST":
        tournament_id = request.form.get("tournament_id", type=int)
        team_id = request.form.get("team_id", type=int)
        try:
            cur.execute(
                "INSERT INTO tournament_registrations (tournament_id, team_id) VALUES (%s, %s);",
                (tournament_id, team_id),
            )
            conn.commit()
            flash("Equipo inscrito correctamente.", "success")
            return redirect(url_for("register_team"))
        except Exception as e:
            conn.rollback()
            flash(f"No se pudo inscribir el equipo: {str(e)}", "error")

    cur.execute("SELECT tournament_id, name FROM tournaments ORDER BY name;")
    tournaments = cur.fetchall()
    cur.execute("SELECT team_id, name FROM teams ORDER BY name;")
    teams = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("register.html", tournaments=tournaments, teams=teams)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
