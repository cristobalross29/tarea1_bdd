import os
import psycopg2
from psycopg2.extras import RealDictCursor

import app as web_app


def db_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        dbname=os.getenv("DB_NAME", "tarea1"),
    )


def assert_true(cond, msg):
    if not cond:
        raise AssertionError(msg)


def main():
    conn = db_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute(
        """
        SELECT t.id_torneo, t.max_equipos, COUNT(i.id_equipo) inscritos
        FROM torneo t
        LEFT JOIN inscripcion i ON i.id_torneo = t.id_torneo
        GROUP BY t.id_torneo, t.max_equipos
        ORDER BY t.id_torneo;
        """
    )
    torneos = cur.fetchall()
    assert_true(torneos, "No hay torneos para ejecutar smoke test")

    torneo_lleno = next((t for t in torneos if t["inscritos"] >= t["max_equipos"]), None)
    torneo_con_cupo = next((t for t in torneos if t["inscritos"] < t["max_equipos"]), None)
    assert_true(torneo_lleno is not None, "No hay torneo lleno para validar rechazo")
    assert_true(torneo_con_cupo is not None, "No hay torneo con cupo para validar inscripción exitosa")

    cur.execute(
        """
        SELECT e.id_equipo
        FROM equipo e
        WHERE NOT EXISTS (
            SELECT 1 FROM inscripcion i
            WHERE i.id_torneo=%s AND i.id_equipo=e.id_equipo
        )
        ORDER BY e.id_equipo
        LIMIT 1;
        """,
        (torneo_lleno["id_torneo"],),
    )
    equipo_para_lleno = cur.fetchone()
    assert_true(equipo_para_lleno is not None, "No hay equipo disponible para probar torneo lleno")

    cur.execute(
        """
        SELECT id_torneo, id_equipo
        FROM inscripcion
        ORDER BY id_torneo, id_equipo
        LIMIT 1;
        """
    )
    inscripcion_existente = cur.fetchone()
    assert_true(inscripcion_existente is not None, "No hay inscripción existente para probar duplicado")

    cur.execute(
        """
        SELECT e.id_equipo
        FROM equipo e
        WHERE NOT EXISTS (
            SELECT 1 FROM inscripcion i
            WHERE i.id_torneo=%s AND i.id_equipo=e.id_equipo
        )
        ORDER BY e.id_equipo
        LIMIT 1;
        """,
        (torneo_con_cupo["id_torneo"],),
    )
    equipo_para_exito = cur.fetchone()
    assert_true(equipo_para_exito is not None, "No hay equipo disponible para probar inscripción exitosa")

    cur.execute(
        """
        SELECT i.id_equipo
        FROM inscripcion i
        WHERE i.id_torneo=%s
        ORDER BY i.id_equipo
        LIMIT 1;
        """,
        (torneo_lleno["id_torneo"],),
    )
    equipo_full_stats = cur.fetchone()
    assert_true(equipo_full_stats is not None, "No hay equipo inscrito para probar estadísticas")

    client = web_app.app.test_client()

    rutas = [
        ("/", {302}),
        ("/torneos", {200}),
        (f"/torneos/{torneo_lleno['id_torneo']}", {200}),
        (f"/estadisticas?id_torneo={torneo_lleno['id_torneo']}", {200}),
        (
            f"/estadisticas?id_torneo={torneo_lleno['id_torneo']}&id_equipo={equipo_full_stats['id_equipo']}",
            {200},
        ),
        ("/busqueda?gamertag=t1", {200}),
        ("/busqueda?pais=Chile", {200}),
        ("/busqueda?equipo=Llama", {200}),
        ("/sponsors?videojuego=Valorant", {200}),
        ("/inscripcion", {200}),
    ]

    for path, expected_codes in rutas:
        resp = client.get(path)
        assert_true(
            resp.status_code in expected_codes,
            f"Ruta {path} respondió {resp.status_code}, esperado {expected_codes}",
        )

    resp_full = client.post(
        "/inscripcion",
        data={
            "id_torneo": str(torneo_lleno["id_torneo"]),
            "id_equipo": str(equipo_para_lleno["id_equipo"]),
            "grupo": "A",
        },
        follow_redirects=True,
    )
    text_full = resp_full.get_data(as_text=True)
    assert_true(
        "alcanzó su número máximo de equipos" in text_full,
        "No se detectó mensaje de torneo lleno en prueba de rechazo",
    )

    resp_dup = client.post(
        "/inscripcion",
        data={
            "id_torneo": str(inscripcion_existente["id_torneo"]),
            "id_equipo": str(inscripcion_existente["id_equipo"]),
            "grupo": "",
        },
        follow_redirects=True,
    )
    text_dup = resp_dup.get_data(as_text=True)
    assert_true(
        "ya está inscrito en ese torneo" in text_dup,
        "No se detectó mensaje de inscripción duplicada",
    )

    resp_ok = client.post(
        "/inscripcion",
        data={
            "id_torneo": str(torneo_con_cupo["id_torneo"]),
            "id_equipo": str(equipo_para_exito["id_equipo"]),
            "grupo": "",
        },
        follow_redirects=True,
    )
    text_ok = resp_ok.get_data(as_text=True)
    assert_true("Inscripción realizada" in text_ok, "No se detectó mensaje de inscripción exitosa")

    cur.execute(
        "SELECT 1 FROM inscripcion WHERE id_torneo=%s AND id_equipo=%s",
        (torneo_con_cupo["id_torneo"], equipo_para_exito["id_equipo"]),
    )
    assert_true(cur.fetchone() is not None, "La inscripción exitosa no quedó persistida en la base")

    cur.close()
    conn.close()
    print("Smoke test OK")


if __name__ == "__main__":
    main()
