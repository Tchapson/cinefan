import psycopg2
import psycopg2.extras

DB_CONFIG = {
    "dbname": "mohamed.fane_db",           # nom de ta base
    "user": "mohamed.fane",                # ton login d'étu
    "host": "sqletud.u-pem.fr",            # serveur de la fac
    "password": "Mohamed123456#",          # ton mot de passe
    "cursor_factory": psycopg2.extras.NamedTupleCursor,
}


def get_connection():
    """
    Ouvre une connexion à la BDD PostgreSQL.
    """
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    return conn


def fetch_all(query, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()


def fetch_one(query, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchone()


def execute(query, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)


# ---------------------------
#  FONCTIONS UTILISATEUR
# ---------------------------

def creer_utilisateur(pseudo, email, mdp_clair):
    """
    Crée un utilisateur dans la table `utilisateur`.
    Pas de hash ici : le mdp est stocké en clair (mdp char(8)).
    """
    execute(
        """
        INSERT INTO utilisateur (pseudo, email, mdp, role_utilisateur)
        VALUES (%s, %s, %s, 'user')
        """,
        (pseudo, email, mdp_clair),
    )


def get_utilisateur_par_email(email):
    """
    Renvoie l'utilisateur correspondant à l'email, ou None.
    """
    return fetch_one(
        "SELECT * FROM utilisateur WHERE email = %s",
        (email,),
    )


def verifier_utilisateur(email, mdp_clair):
    """
    Vérifie email + mot de passe.
    On utilise la BDD telle quelle (mdp stocké en clair).
    Renvoie l'utilisateur si OK, sinon None.
    """
    return fetch_one(
        "SELECT * FROM utilisateur WHERE email = %s AND mdp = %s",
        (email, mdp_clair),
    )
