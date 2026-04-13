import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg2
import psycopg2.extras

# 1. Charger .env en premier
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

# 2. Neutraliser les variables PostgreSQL parasites (système / libpq)
for _var in ("PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE",
             "PGSERVICE", "PGSERVICEFILE", "PGPASSFILE"):
    os.environ.pop(_var, None)

# 3. Forcer l'encodage client UTF-8
os.environ["PGCLIENTENCODING"] = "UTF8"


def connect():
    """
    Retourne une connexion PostgreSQL configurée depuis les variables d'environnement.
    Utilisé par fonctions.py comme point d'entrée unique.
    """
    try:
        conn = psycopg2.connect(
            dbname=os.environ.get("DB_NAME",     "cinefan"),
            user=os.environ.get("DB_USER",       "postgres"),
            host=os.environ.get("DB_HOST",       "localhost"),
            password=os.environ.get("DB_PASSWORD", ""),
            port=int(os.environ.get("DB_PORT",   5433)),
            options="-c client_encoding=UTF8",
        )
        conn.autocommit = True
        return conn
    except Exception as e:
        raw = repr(e).encode("utf-8", errors="replace").decode("utf-8")
        raise RuntimeError(f"Connexion PostgreSQL impossible : {raw}") from None
