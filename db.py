print(">>> db.py CHARGÉ depuis :", __file__)

import psycopg2
import psycopg2.extras
import bcrypt

# ------------------------------------------
# CONFIGURATION BDD a adapter 
# ------------------------------------------
DB_CONFIG = {
    "dbname": "cinefan",
    "user": "postgres",
    "host": "localhost",
    "password": "Tchapson07@",
    "port": 5433,
    "cursor_factory": psycopg2.extras.NamedTupleCursor,
}


def get_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        return conn
    except Exception as e:
        print("ERREUR DE CONNEXION :", e)
        raise


# ------------------------------------------
# FONCTIONS DE BASE
# ------------------------------------------
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


# ------------------------------------------
# HASHAGE DU MOT DE PASSE (bcrypt)
# ------------------------------------------
def hash_password(mdp_clair: str) -> str:
    """
    Reçoit un mot de passe en clair → renvoie une version hachée (UTF-8).
    """
    hashed = bcrypt.hashpw(mdp_clair.encode("utf-8"), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(mdp_clair: str, hash_en_bdd: str) -> bool:
    """
    Vérifie si le mot de passe correspond au hash.
    """
    try:
        return bcrypt.checkpw(mdp_clair.encode("utf-8"), hash_en_bdd.encode("utf-8"))
    except:
        return False



# ------------------------------------------
# FONCTIONS UTILISATEUR
# ------------------------------------------
def creer_utilisateur(pseudo, email, mdp_clair):
    """
    Crée un utilisateur en stockant un mot de passe haché.
    """
    hash_final = hash_password(mdp_clair)

    execute(
        """
        INSERT INTO utilisateur (pseudo, email, mdp, role_utilisateur)
        VALUES (%s, %s, %s, 'user')
        """,
        (pseudo, email, hash_final),
    )


def get_utilisateur_par_email(email):
    """
    Renvoie un utilisateur unique par email ou None.
    """
    return fetch_one(
        "SELECT * FROM utilisateur WHERE LOWER(email) = LOWER(%s)",
        (email,),
    )


def verifier_utilisateur(email, mdp_clair):
    """
    Vérifie que l'email existe, puis vérifie le mot de passe haché.
    Renvoie l'utilisateur complet si OK, sinon None.
    """
    user = fetch_one(
        "SELECT * FROM utilisateur WHERE LOWER(email) = LOWER(%s)",
        (email,),
    )

    if not user:
        print(">>> Email introuvable en BDD")
        return None

    if not verify_password(mdp_clair, user.mdp):
        print(">>> Mot de passe incorrect")
        return None

    print(">>> Authentification réussie pour :", user.email)
    return user

creer_utilisateur("TestUser", "test@mail.com", "azerty123")

