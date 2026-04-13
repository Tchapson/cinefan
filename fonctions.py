
"""
═══════════════════════════════════════════════════════════════════════════
    FONCTIONS DE GESTION DE BASE DE DONNÉES - PROJET CINEFAN
═══════════════════════════════════════════════════════════════════════════
    
    ce fichier contient toutes les fonctions pour travailler avec la BDD.
    organisé par catégories: utilisateurs, oeuvres, commentaires, etc.
    ;))
═══════════════════════════════════════════════════════════════════════════
    
"""

import psycopg2.extras
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import date
from db import connect
from flask import url_for

# ═══════════════════════════════════════════════════════════════════════════
#                           HELPERS DE CONNEXION
# ═══════════════════════════════════════════════════════════════════════════

def get_connection():
    """
    Crée une connexion PostgreSQL 
    Retourne des résultats sous forme de named tuples pour accès facile (ex: ligne.nom)
    """
    conn = connect()
    conn.autocommit = True
    conn.cursor_factory = psycopg2.extras.NamedTupleCursor
    return conn


def fetch_all(query, params=None):
    """Exécute une requête et renvoie TOUTES les lignes!"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()


def fetch_one(query, params=None):
    """Exécute une requête et renvoie UNE SEULE ligne(ou None)"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchone()


def execute(query, params=None):
    """Exécute une requête sans retourner de résultat === (INSERT, UPDATE, DELETE)"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)


# ═══════════════════════════════════════════════════════════════════════════
#                          CLASSE UTILISATEUR
# ═══════════════════════════════════════════════════════════════════════════

class Utilisateur:
    """Représente un utilisateur du site avec ses droits"""
    
    def __init__(self, id_utilisateur, pseudo, email, role): 
        self.id_utilisateur = id_utilisateur
        self.pseudo = pseudo
        self.email = email 
        self.role = role

    def is_admin(self):
        """Est-ce que cet utilisateur est admin?"""
        return self.role == "admin"
    
    def can_comment(self):
        """Peut-il laisser des commentaires?(pour l'instant, tout le monde peut)"""
        return True
    
    def can_delete_comment(self, comment_id):
        """Peut-il supprimer CE commentaire?(admin ou auteur seulement)"""
        if self.is_admin():
            return True
        
        comment = fetch_one(
            "SELECT * FROM commentaire WHERE id_commentaire = %s",
            (comment_id,)
        )
        return comment and comment.id_utilisateur == self.id_utilisateur

    def get_comments(self):
        """Récupère tous les commentaires de cet utilisateur"""
        return fetch_all(
            "SELECT * FROM commentaire WHERE id_utilisateur = %s ORDER BY date_commentaire DESC",
            (self.id_utilisateur,)
        )


# ═══════════════════════════════════════════════════════════════════════════
#                      GESTION DES UTILISATEURS
# ═══════════════════════════════════════════════════════════════════════════

def creer_utilisateur(pseudo, email, mdp_clair):
    """
    Crée un nouvel utilisateur avec mot de passe hashé
    Par défaut, il obtient le rôle 'user'
    """
    mdp_hash = generate_password_hash(mdp_clair)
    
    execute(
        """
        INSERT INTO utilisateur (pseudo, email, mdp, role_utilisateur)
        VALUES (%s, %s, %s, 'user')
        """,
        (pseudo, email, mdp_hash)
    )


def get_utilisateur_par_email(email):
    """Cherche un utilisateur par son email. Renvoie None si pas trouvé"""
    return fetch_one(
        "SELECT * FROM utilisateur WHERE email = %s",
        (email,)
    )


def get_utilisateur_par_id(id_utilisateur):
    """Cherche un utilisateur par son ID. Renvoie None si pas trouvé"""
    return fetch_one(
        "SELECT * FROM utilisateur WHERE id_utilisateur = %s",
        (id_utilisateur,)
    )

def rechercher_utilisateurs(texte):
    """Cherche des utilisateurs par pseudo ou email"""
    return fetch_all(
        """
        SELECT id_utilisateur, pseudo, email, role_utilisateur
        FROM utilisateur
        WHERE pseudo ILIKE %s OR email ILIKE %s
        ORDER BY pseudo
        """,
        (f"%{texte}%", f"%{texte}%"))

def get_id_par_email(email):
    """Récupère juste l'ID d'un utilisateur à partir de son email"""
    return fetch_one(
        "SELECT id_utilisateur FROM utilisateur WHERE email = %s",
        (email,)
    )


def editer_profil(id_utilisateur, pseudo=None, email=None, mdp=None):
    """
    Modifie le profil d'un utilisateur avec les paramètres donnés
    """
    nouvelles = []
    parametres = []
    
    if email:
        nouvelles.append("email = %s")
        parametres.append(email)
    
    if pseudo: nouvelles.append("pseudo = %s"); parametres.append(pseudo)
    
    if mdp: nouvelles.append("mdp = %s"); parametres.append(generate_password_hash(mdp))    
    
    if not nouvelles: return  
    
    parametres.append(id_utilisateur)
    query = f"UPDATE utilisateur SET {', '.join(nouvelles)} WHERE id_utilisateur = %s"
    
    execute(query, parametres)


def bannir_utilisateur(id_utilisateur):
    """Met un utilisateur en mode 'banni' ==> il ne pourra plus se connecter"""
    execute(
        "UPDATE utilisateur SET role_utilisateur = 'banni' WHERE id_utilisateur = %s",
        (id_utilisateur,)
    )


def debannir_utilisateur(id_utilisateur):
    """Réhabilite un utilisateur banni ==> il redevient 'user' normal"""
    execute(
        "UPDATE utilisateur SET role_utilisateur = 'user' WHERE id_utilisateur = %s",
        (id_utilisateur,)
    )


def est_banni(id_utilisateur):
    """Vérifie si un utilisateur est banni. Return True ou False"""
    user = fetch_one(
        "SELECT role_utilisateur FROM utilisateur WHERE id_utilisateur = %s",
        (id_utilisateur,)
    )
    return user and user.role_utilisateur == "banni"


def verifier_utilisateur(email, mdp_clair):
    """
    Vérifie email + mot de passe pour la connexion.
    Renvoie l'utilisateur si c'est bon, sinon None
    """
    user = fetch_one(
        "SELECT * FROM utilisateur WHERE email = %s",
        (email,)
    )
    
    if user and check_password_hash(user.mdp, mdp_clair):
        return user
    
    return None


def get_admin_user(id_utilisateur=None):
    """Retourne l'utilisateur admin connecté, ou None sinon"""
    if not id_utilisateur:
        return None
    u = get_utilisateur_par_id(id_utilisateur)
    m = fetch_one("SELECT role_utilisateur FROM utilisateur WHERE id_utilisateur = %s", (id_utilisateur,))
    if not m or m.role_utilisateur != "admin":
        return None
    return u

# ═══════════════════════════════════════════════════════════════════════════
#                         GESTION DES OEUVRES
# ═══════════════════════════════════════════════════════════════════════════

def creer_oeuvre(titre, type_oeuvre, date_creation, description_oeuvre=None, numero_volet_saison=None):
    """
    Cr?e une nouvelle oeuvre(film, s?rie, anime, etc......)
    Retourne l'id cr??.
    """
    row = fetch_one(
        """
        INSERT INTO oeuvre (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id_oeuvre
        """
        ,
        (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre)
    )
    return row.id_oeuvre if row else None


# Admin update helpers
def update_oeuvre(id_oeuvre, titre=None, type_oeuvre=None, date_creation=None, description_oeuvre=None, numero_volet_saison=None):
    """Met a jour les champs fournis pour une oeuvre."""
    champs = []
    params = []
    if titre is not None:
        champs.append("titre = %s")
        params.append(titre)
    if type_oeuvre is not None:
        champs.append("type_oeuvre = %s")
        params.append(type_oeuvre)
    if date_creation is not None:
        champs.append("date_creation = %s")
        params.append(date_creation)
    if description_oeuvre is not None:
        champs.append("description_oeuvre = %s")
        params.append(description_oeuvre)
    if numero_volet_saison is not None:
        champs.append("numero_volet_saison = %s")
        params.append(numero_volet_saison)
    if not champs:
        return
    params.append(id_oeuvre)
    query = f"UPDATE oeuvre SET {', '.join(champs)} WHERE id_oeuvre = %s"
    execute(query, params)


def remplacer_photo_oeuvre(id_oeuvre, chemin):
    """Remplace la photo principale d'une oeuvre."""
    execute("DELETE FROM photo WHERE id_oeuvre = %s", (id_oeuvre,))
    execute("INSERT INTO photo (id_oeuvre, chemin) VALUES (%s, %s)", (id_oeuvre, chemin))


def get_oeuvre(id_oeuvre):
    """Récupère toutes les infos d'une oeuvre par son ID + première photo"""
    return fetch_one(
        """
        SELECT o.*,
               (SELECT chemin FROM photo WHERE id_oeuvre = o.id_oeuvre LIMIT 1) AS photo
        FROM oeuvre o
        WHERE o.id_oeuvre = %s
        """,
        (id_oeuvre,)
    )


def oeuvre_existe(id_oeuvre):
    """Vérifie rapidement si une oeuvre existe(true/false)"""
    result = fetch_one(
        "SELECT 1 FROM oeuvre WHERE id_oeuvre = %s",
        (id_oeuvre,)
    )
    return result is not None


def get_toutes_oeuvres():
    """Récupère toutes les oeuvres, triées par titre"""
    return fetch_all("SELECT * FROM oeuvre ORDER BY titre")


def rechercher_oeuvres(texte):
    """
    Cherche des oeuvres par titre ou description
    Insensible à la casse(majuscules/minuscules)
    """
    return fetch_all(
        """
        SELECT * FROM oeuvre 
        WHERE LOWER(titre) LIKE LOWER(%s) 
           OR LOWER(description_oeuvre) LIKE LOWER(%s) 
        ORDER BY titre
        """,
        (f"%{texte}%", f"%{texte}%")
    )


def supprimer_oeuvre(id_oeuvre):
    """Supprime une oeuvre définitivement!!!!!!!"""
    execute(
        "DELETE FROM oeuvre WHERE id_oeuvre = %s",
        (id_oeuvre,)
    )


def mettre_a_jour_oeuvre(id_oeuvre, titre=None, type_oeuvre=None, date_creation=None, 
                         description_oeuvre=None, numero_volet_saison=None):
    """
    Modifie une oeuvre existante avec les paramètres donnés
    """
    nouvelles = []
    parametres = []
    
    if titre: nouvelles.append("titre = %s"); parametres.append(titre)
    
    if type_oeuvre: nouvelles.append("type_oeuvre = %s"); parametres.append(type_oeuvre)
    
    if date_creation: nouvelles.append("date_creation = %s"); parametres.append(date_creation)
    
    if description_oeuvre is not None: nouvelles.append("description_oeuvre = %s"); parametres.append(description_oeuvre)
    
    if numero_volet_saison is not None: nouvelles.append("numero_volet_saison = %s"); parametres.append(numero_volet_saison)    
    
    if not nouvelles: return 
    
    parametres.append(id_oeuvre)
    query = f"UPDATE oeuvre SET {', '.join(nouvelles)} WHERE id_oeuvre = %s"
    
    execute(query, parametres)


# ═══════════════════════════════════════════════════════════════════════════
#                        GESTION DES COMMENTAIRES
# ═══════════════════════════════════════════════════════════════════════════

def creer_commentaire(contenu, id_utilisateur, id_oeuvre):
    """
    Ajoute un commentaire sur une oeuvre
    Min 5 caractères, maximum 5000 ===> une ValueError sinon
    """
    contenu_nettoye = contenu.strip()
    
    if not contenu_nettoye or len(contenu_nettoye) < 5:
        raise ValueError("Le commentaire doit contenir au moins 5 caractères !!")
    
    if len(contenu_nettoye) > 5000:
        raise ValueError("Le commentaire ne peut pas dépasser 5000 caractères !!!")
    
    execute(
        """
        INSERT INTO commentaire (contenu, date_commentaire, id_utilisateur, id_oeuvre)
        VALUES (%s, %s, %s, %s)
        """,
        (contenu_nettoye, date.today(), id_utilisateur, id_oeuvre)
    )


def get_commentaires_oeuvre(id_oeuvre):
    """
    Récupère tous les commentaires d'une oeuvre avec le pseudo de l'auteur
    Triés du plus récent au plus ancien
    """
    return fetch_all(
        """
        SELECT c.*, u.pseudo 
        FROM commentaire AS c 
        JOIN utilisateur AS u ON c.id_utilisateur = u.id_utilisateur 
        WHERE c.id_oeuvre = %s 
        ORDER BY c.date_commentaire DESC
        """,
        (id_oeuvre,)
    )

def get_commentaires_page_admin(where, params, limit, offset):
    return fetch_all(
        f'''
        SELECT c.id_commentaire, c.contenu AS commentaire, c.date_commentaire, c.id_utilisateur, u.pseudo, u.role_utilisateur, o.titre
        FROM commentaire c
        JOIN utilisateur u ON c.id_utilisateur = u.id_utilisateur
        JOIN oeuvre o ON c.id_oeuvre = o.id_oeuvre
        {where}
        ORDER BY c.date_commentaire DESC
        LIMIT %s OFFSET %s
        ''',
        params + [limit, offset]
    )

def get_count_commentaires_admin(where, params):
    return fetch_one(f"SELECT COUNT(*) AS c FROM commentaire c {where}", params)


def supprimer_commentaire(id_commentaire):
    """Supprime un commentaire définitivement!!!!!!!!!!"""
    execute(
        "DELETE FROM commentaire WHERE id_commentaire = %s",
        (id_commentaire,)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                         GESTION DES FAVORIS
# ═══════════════════════════════════════════════════════════════════════════

def ajouter_favori(id_utilisateur, id_oeuvre):
    """
    Ajoute une oeuvre aux favoris d'un utilisateur
    Si déjà en favoris, ne fait rien --> avec (ON CONFLICT)
    """
    utilisateur = fetch_one("SELECT id_utilisateur FROM utilisateur WHERE id_utilisateur = %s", (id_utilisateur,))
    if not utilisateur:
        raise ValueError(f"L'utilisateur avec l'id {id_utilisateur} n'existe pas!!!!")
    
    execute(
        """
        INSERT INTO favoris (id_utilisateur, id_oeuvre, date_ajout)
        VALUES (%s, %s, %s)
        ON CONFLICT (id_utilisateur, id_oeuvre) DO NOTHING
        """,
        (id_utilisateur, id_oeuvre, date.today())
    )


def supprimer_favori(id_utilisateur, id_oeuvre):
    """Retire une oeuvre des favoris"""
    execute(
        "DELETE FROM favoris WHERE id_utilisateur = %s AND id_oeuvre = %s",
        (id_utilisateur, id_oeuvre)
    )


def get_favoris_utilisateur(id_utilisateur):
    """
    Récupère tous les favoris d'un utilisateur avec les infos des oeuvres
    """
    return fetch_all(
        """
        SELECT f.*, o.titre, o.type_oeuvre, o.date_creation 
        FROM favoris f 
        JOIN oeuvre o ON f.id_oeuvre = o.id_oeuvre 
        WHERE f.id_utilisateur = %s 
        ORDER BY f.date_ajout DESC
        """,
        (id_utilisateur,)
    )


def est_favori(id_utilisateur, id_oeuvre):
    """Vérifie si une oeuvre est dans les favoris d'un utilisateur"""
    result = fetch_one(
        "SELECT 1 FROM favoris WHERE id_utilisateur = %s AND id_oeuvre = %s",
        (id_utilisateur, id_oeuvre)
    )
    return result is not None


# ═══════════════════════════════════════════════════════════════════════════
#                       GESTION DES CATÉGORIES/GENRES
# ═══════════════════════════════════════════════════════════════════════════

def creer_categorie(nom_cat):
    """Crée une nouvelle catégorie/genre. Ignore si elle existe déjà"""
    execute(
        "INSERT INTO categorie (nom_cat) VALUES (%s) ON CONFLICT (nom_cat) DO NOTHING",
        (nom_cat,)
    )


def get_toutes_categories():
    """Récupère toutes les catégories triées par nom"""
    return fetch_all("SELECT * FROM categorie ORDER BY nom_cat")


def ajouter_genre_oeuvre(id_oeuvre, nom_cat):
    """Attribue un genre à une oeuvre, ignore si déjà attribué"""
    execute(
        "INSERT INTO appartient (id_oeuvre, nom_cat) VALUES (%s, %s) ON CONFLICT DO NOTHING",
        (id_oeuvre, nom_cat)
    )


def get_genres_oeuvre(id_oeuvre):
    """Récupère tous les genres d'une oeuvre"""
    return fetch_all(
        "SELECT nom_cat FROM appartient WHERE id_oeuvre = %s",
        (id_oeuvre,)
    )


def supprimer_genre_oeuvre(id_oeuvre, nom_cat):
    """Retire un genre d'une oeuvre"""
    execute(
        "DELETE FROM appartient WHERE id_oeuvre = %s AND nom_cat = %s",
        (id_oeuvre, nom_cat)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                       GESTION DES RÉALISATEURS
# ═══════════════════════════════════════════════════════════════════════════

def ajouter_realisateur(id_artiste, id_oeuvre):
    """Attribue un réalisateur à une oeuvre, ignore si déjà attribué"""
    execute(
        "INSERT INTO realise (id_artiste, id_oeuvre) VALUES (%s, %s) ON CONFLICT DO NOTHING",
        (id_artiste, id_oeuvre)
    )


def get_realisateurs_oeuvre(id_oeuvre):
    """Récupère tous les réalisateurs d'une oeuvre avec leurs noms"""
    return fetch_all(
        """
        SELECT a.id_artiste, a.nom, a.prenom 
        FROM realise AS r 
        JOIN artiste AS a ON r.id_artiste = a.id_artiste 
        WHERE r.id_oeuvre = %s
        """,
        (id_oeuvre,)
    )


def supprimer_realisateur(id_artiste, id_oeuvre):
    """Retire un réalisateur d'une oeuvre"""
    execute(
        "DELETE FROM realise WHERE id_oeuvre = %s AND id_artiste = %s",
        (id_oeuvre, id_artiste)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                    GESTION DES ARTISTES & PERSONNAGES
# ═══════════════════════════════════════════════════════════════════════════

def creer_artiste(nom, prenom, date_naissance, biographie):
    """Crée un nouvel artiste(acteur, réalisateur, etc..........)"""
    execute(
        """
        INSERT INTO artiste (nom, prenom, date_naissance, biographie)
        VALUES (%s, %s, %s, %s)
        """,
        (nom, prenom, date_naissance, biographie)
    )


def get_artiste(id_artiste):
    """Récupère toutes les infos d'un artiste par son ID"""
    return fetch_one(
        "SELECT * FROM artiste WHERE id_artiste = %s",
        (id_artiste,)
    )


def artiste_existe(id_artiste):
    """Vérifie si un artiste existe"""
    result = fetch_one(
        "SELECT 1 FROM artiste WHERE id_artiste = %s",
        (id_artiste,)
    )
    return result is not None


def rechercher_artistes(texte):
    """Cherche des artistes par nom ou prénom"""
    return fetch_all(
        "SELECT * FROM artiste WHERE nom LIKE %s OR prenom LIKE %s ORDER BY nom",
        (f"%{texte}%", f"%{texte}%")
    )


def supprimer_artiste(id_artiste):
    """Supprime un artiste définitivement!!!!!!!!!!"""
    execute(
        "DELETE FROM artiste WHERE id_artiste = %s",
        (id_artiste,)
    )


def creer_personnage(libelle):
    """Crée un nouveau personnage(ex: 'Pipi PUPA', 'popo PAPA')"""
    execute(
        "INSERT INTO personnage (libelle) VALUES (%s)",
        (libelle,)
    )


def get_tous_personnages():
    """Récupère tous les personnages, triés par nom"""
    return fetch_all("SELECT * FROM personnage ORDER BY libelle")


def get_personnages_avec_acteurs(id_oeuvre):
    """
    Pour une oeuvre, récupère tous les personnages avec leurs acteurs
    ex: "PIPI PUPA joué par PLOPLA Jr."
    """
    return fetch_all(
        """
        SELECT p.id_personnage, p.libelle, a.id_artiste, a.nom, a.prenom
        FROM joue AS j
        JOIN personnage AS p ON j.id_personnage = p.id_personnage
        JOIN artiste AS a ON j.id_artiste = a.id_artiste
        WHERE j.id_oeuvre = %s
        ORDER BY p.libelle
        """,
        (id_oeuvre,)
    )


def ajouter_acteur_oeuvre(id_artiste, id_oeuvre, id_personnage):
    """Fait jouer un acteur dans une oeuvre pour un personnage donné"""
    execute(
        """
        INSERT INTO joue (id_artiste, id_oeuvre, id_personnage)
        VALUES (%s, %s, %s)
        """,
        (id_artiste, id_oeuvre, id_personnage)
    )


def get_acteurs_oeuvre(id_oeuvre):
    """Récupère tous les acteurs d'une oeuvre avec les personnages qu'ils jouent"""
    return fetch_all(
        """
        SELECT a.id_artiste, a.nom, a.prenom, p.libelle AS personnage, p.id_personnage
        FROM joue j
        JOIN artiste a ON j.id_artiste = a.id_artiste
        JOIN personnage p ON j.id_personnage = p.id_personnage
        WHERE j.id_oeuvre = %s
        """,
        (id_oeuvre,)
    )


def supprimer_acteur_oeuvre(id_artiste, id_oeuvre):
    """Retire un acteur d'une oeuvre!!!!!!!!!"""
    execute(
        "DELETE FROM joue WHERE id_artiste = %s AND id_oeuvre = %s",
        (id_artiste, id_oeuvre)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                          STATISTIQUES
# ═══════════════════════════════════════════════════════════════════════════

def get_stats_generales():
    """
    Récupère les stats globales du site en un seul appel:
    (nombre d'oeuvres, artistes, utilisateurs et commentaires)
    """
    return fetch_one(
        """
        SELECT 
            (SELECT COUNT(*) FROM oeuvre) AS nb_oeuvres,
            (SELECT COUNT(*) FROM artiste) AS nb_artistes,
            (SELECT COUNT(*) FROM utilisateur) AS nb_utilisateurs,
            (SELECT COUNT(*) FROM commentaire) AS nb_commentaires
        """
    )


def get_top_oeuvres_commentees(limit=10):
    """
    Les oeuvres les plus commentées.
    """
    return fetch_all(
        """
        SELECT o.id_oeuvre, o.titre, o.type_oeuvre, COUNT(c.id_commentaire) AS nb_commentaires
        FROM oeuvre AS o
        LEFT JOIN commentaire AS c ON o.id_oeuvre = c.id_oeuvre
        GROUP BY o.id_oeuvre, o.titre, o.type_oeuvre
        ORDER BY nb_commentaires DESC
        LIMIT %s
        """,
        (limit,)
    )


def get_stats_utilisateurs():
    """
    Stats de tous les utilisateurs(sauf les bannis):
    combien de commentaires et de favoris ils ont
    """
    return fetch_all(
        """
        SELECT 
            u.id_utilisateur,
            u.pseudo,
            COUNT(DISTINCT c.id_commentaire) AS nb_commentaires,
            COUNT(DISTINCT f.id_oeuvre) AS nb_favoris
        FROM utilisateur u
        LEFT JOIN commentaire c ON u.id_utilisateur = c.id_utilisateur
        LEFT JOIN favoris f ON u.id_utilisateur = f.id_utilisateur
        WHERE u.role_utilisateur != 'banni'
        GROUP BY u.id_utilisateur, u.pseudo
        ORDER BY nb_commentaires DESC
        """
    )


def get_top_acteurs_genres(nom_cat=None, limit=10):
    """
    Les acteurs les plus actifs par genre
    ça filtre par ce genre ou ça montre tous les acteurs genre TOUTES CATÉGORIES
    """
    if nom_cat:
        return fetch_all(
            """
            SELECT a.id_artiste, a.nom, a.prenom, COUNT(DISTINCT j.id_oeuvre) AS nb_films
            FROM artiste a
            JOIN joue j ON a.id_artiste = j.id_artiste
            JOIN appartient ap ON j.id_oeuvre = ap.id_oeuvre
            WHERE ap.nom_cat = %s
            GROUP BY a.id_artiste, a.nom, a.prenom
            ORDER BY nb_films DESC
            LIMIT %s
            """,
            (nom_cat, limit)
        )
    else:
        return fetch_all(
            """
            SELECT a.id_artiste, a.nom, a.prenom, COUNT(DISTINCT j.id_oeuvre) AS nb_films
            FROM artiste a
            JOIN joue j ON a.id_artiste = j.id_artiste
            GROUP BY a.id_artiste, a.nom, a.prenom
            ORDER BY nb_films DESC
            LIMIT %s
            """,
            (limit,)
        )


def get_moyenne_commentaires_genre(nom_cat=None):
    """
    Calcule le nombre moyen de commentaires par oeuvre pour chaque genre
    ça montre juste ce genre ou tous les genres 
    """
    if nom_cat:
        return fetch_one(
            """
            SELECT 
                c.nom_cat,
                COUNT(DISTINCT a.id_oeuvre) AS nb_oeuvres,
                COUNT(com.id_commentaire) AS total_commentaires,
                1.0 * COUNT(com.id_commentaire) / COUNT(DISTINCT a.id_oeuvre) AS moyenne_commentaires
            FROM categorie AS c
            LEFT JOIN appartient AS a ON c.nom_cat = a.nom_cat
            LEFT JOIN commentaire AS com ON a.id_oeuvre = com.id_oeuvre
            WHERE c.nom_cat = %s
            GROUP BY c.nom_cat
            HAVING COUNT(DISTINCT a.id_oeuvre) > 0
            """,
            (nom_cat,)
        )
    else:
        return fetch_all(
            """
            SELECT 
                c.nom_cat,
                COUNT(DISTINCT a.id_oeuvre) AS nb_oeuvres,
                COUNT(com.id_commentaire) AS total_commentaires,
                1.0 * COUNT(com.id_commentaire) / COUNT(DISTINCT a.id_oeuvre) AS moyenne_commentaires
            FROM categorie AS c
            LEFT JOIN appartient AS a ON c.nom_cat = a.nom_cat
            LEFT JOIN commentaire AS com ON a.id_oeuvre = com.id_oeuvre
            GROUP BY c.nom_cat
            HAVING COUNT(DISTINCT a.id_oeuvre) > 0
            ORDER BY moyenne_commentaires DESC
            """
        )


# ═══════════════════════════════════════════════════════════════════════════
#                     LIENS ENTRE OEUVRES (Suites, Prequels, etc.)
# ═══════════════════════════════════════════════════════════════════════════

def get_liens_oeuvre(id_oeuvre):
    """
    Récupère toutes les oeuvres liées à celle-ci
    ex: suites, prequels, spin-offs, etc...........
    """
    return fetch_all(
        """
        SELECT 
            o2.id_oeuvre AS id_liee, 
            o2.titre, 
            l.type_lien,
            (SELECT chemin FROM photo WHERE id_oeuvre = o2.id_oeuvre LIMIT 1) AS photo
        FROM lien l
        JOIN oeuvre o2 ON o2.id_oeuvre = l.id_oeuvre2
        WHERE l.id_oeuvre1 = %s
        """,
        (id_oeuvre,)
    )


def ajouter_lien_oeuvre(id_oeuvre1, id_oeuvre2, type_lien):
    """
    Crée un lien entre deux oeuvres
    ex: 'suite', 'prequel', 'spin-off', etc..................
    """
    execute(
        "INSERT INTO lien (id_oeuvre1, id_oeuvre2, type_lien) VALUES (%s, %s, %s)",
        (id_oeuvre1, id_oeuvre2, type_lien)
    )


def supprimer_lien_oeuvre(id_oeuvre1, id_oeuvre2):
    """supprime le lien entre deux oeuvres!!!!!!!!!!!!!!!!!!!!!"""
    execute(
        "DELETE FROM lien WHERE id_oeuvre1 = %s AND id_oeuvre2 = %s",
        (id_oeuvre1, id_oeuvre2)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                      FONCTIONS "RÉCENTS" (Nouveautés)
# ═══════════════════════════════════════════════════════════════════════════

def get_oeuvres_recentes(limit=6):
    """Les dernières oeuvres ajoutées au site"""
    return fetch_all(
        "SELECT * FROM oeuvre ORDER BY id_oeuvre DESC LIMIT %s",
        (limit,)
    )


def get_commentaires_recents(limit=6):
    """
    Les commentaires les plus récents sur le site
    Inclut le pseudo de l'auteur et le titre de l'oeuvre
    """
    return fetch_all(
        """
        SELECT c.*, u.pseudo, o.titre
        FROM commentaire AS c
        JOIN utilisateur AS u ON c.id_utilisateur = u.id_utilisateur
        JOIN oeuvre AS o ON c.id_oeuvre = o.id_oeuvre
        ORDER BY c.date_commentaire DESC
        LIMIT %s
        """,
        (limit,)
    )


def get_artistes_recents(limit=6):
    """Les derniers artistes ajoutés au site"""
    return fetch_all(
        "SELECT * FROM artiste ORDER BY id_artiste DESC LIMIT %s",
        (limit,)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                      FONCTIONS UTILITAIRES GÉNÉRIQUES
# ═══════════════════════════════════════════════════════════════════════════

def compter_lignes(table):
    """
    Compte le nombre de lignes dans n'importe quelle table
    seulement les tables de la liste sont autorisées
    """
    tables_valides = [
        'oeuvre', 'artiste', 'utilisateur', 'commentaire', 'categorie',
        'personnage', 'favoris', 'appartient', 'realise', 'joue', 'lien'
    ]
    
    if table not in tables_valides:
        raise ValueError(f"Table non autorisée: {table}")
    
    return fetch_one(f"SELECT COUNT(*) AS c FROM {table}")


def get_recents(table, limit=6):
    """
    Récupère les derniers éléments ajoutés dans n'importe quelle table
    eulement les tables configurées sont autorisées
    """
    tables_config = {
        'oeuvre': ('id_oeuvre', 'id_oeuvre'),
        'artiste': ('id_artiste', 'id_artiste'),
        'utilisateur': ('id_utilisateur', 'id_utilisateur'),
        'commentaire': ('id_commentaire', 'date_commentaire'),
        'categorie': ('nom_cat', 'nom_cat'),
        'personnage': ('id_personnage', 'id_personnage'),
        'favoris': ('id_utilisateur', 'date_ajout'),
        'lien': ('id_oeuvre1', 'id_oeuvre1')
    }
    
    if table not in tables_config:
        raise ValueError(f"Table non autorisée: {table}")
    
    id_col, order_col = tables_config[table]
    
    return fetch_all(
        f"SELECT * FROM {table} ORDER BY {order_col} DESC LIMIT %s",
        (limit,)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                              FONCTIONS PHOTOS
# ═══════════════════════════════════════════════════════════════════════════

def get_photo_oeuvre(id_oeuvre):
    """Récupère la première photo d'une oeuvre"""
    return fetch_one(
        "SELECT chemin FROM photo WHERE id_oeuvre = %s LIMIT 1",
        (id_oeuvre,)
    )

def ajouter_photo_oeuvre(id_oeuvre, chemin):
    """Ajoute une photo pour une oeuvre"""
    execute("INSERT INTO photo (id_oeuvre, chemin) VALUES (%s, %s)", (id_oeuvre, chemin))

def get_photos_oeuvres(oeuvres):
    """
    Récupère les photos pour une liste d'oeuvres
    Retourne un dictionnaire {id_oeuvre: chemin_photo}
    """
    if not oeuvres:
        return {}
    
    ids = [o.id_oeuvre for o in oeuvres]
    photos = fetch_all(
        """
        SELECT DISTINCT ON (id_oeuvre) id_oeuvre, chemin 
        FROM photo 
        WHERE id_oeuvre = ANY(%s)
        """,
        (ids,)
    )
    return {p.id_oeuvre: p.chemin for p in photos}


def get_oeuvres_avec_photos(limit=10):
    """Récupère les oeuvres récentes avec leurs photos"""
    return fetch_all(
        """
        SELECT o.*, p.chemin as photo
        FROM oeuvre o
        LEFT JOIN LATERAL (
            SELECT chemin FROM photo WHERE id_oeuvre = o.id_oeuvre LIMIT 1
        ) AS p ON true
        ORDER BY o.id_oeuvre DESC
        LIMIT %s
        """,
        (limit,)
    )


def get_toutes_oeuvres_avec_photos():
    """Récupère toutes les oeuvres avec leurs photos"""
    return fetch_all(
        """
        SELECT o.*, p.chemin as photo
        FROM oeuvre o
        LEFT JOIN LATERAL (
            SELECT chemin FROM photo WHERE id_oeuvre = o.id_oeuvre LIMIT 1
        ) p ON true
        ORDER BY o.titre
        """
    )

def normalize_photo(photo):
    if not photo:
        return None
    photo = str(photo)
    if photo.startswith(("http://", "https://", "/")):
        return photo
    return url_for("static", filename=photo)

def get_top_utilisateurs(limit=5):
    return fetch_all(
        """
        SELECT 
            u.id_utilisateur,
            u.pseudo,
            COUNT(DISTINCT c.id_commentaire) AS nb_commentaires,
            COUNT(DISTINCT f.id_oeuvre) AS nb_favoris,
            COUNT(DISTINCT c.id_commentaire) + COUNT(DISTINCT f.id_oeuvre) AS score,
            CASE 
                WHEN COUNT(DISTINCT c.id_commentaire) + COUNT(DISTINCT f.id_oeuvre) <= 5 THEN 1
                WHEN COUNT(DISTINCT c.id_commentaire) + COUNT(DISTINCT f.id_oeuvre) <= 15 THEN 2
                WHEN COUNT(DISTINCT c.id_commentaire) + COUNT(DISTINCT f.id_oeuvre) <= 30 THEN 3
                WHEN COUNT(DISTINCT c.id_commentaire) + COUNT(DISTINCT f.id_oeuvre) <= 50 THEN 4
                ELSE 5
            END AS level
        FROM utilisateur AS u
        LEFT JOIN commentaire AS c ON u.id_utilisateur = c.id_utilisateur
        LEFT JOIN favoris AS f ON u.id_utilisateur = f.id_utilisateur
        WHERE u.role_utilisateur != 'banni'
        GROUP BY u.id_utilisateur, u.pseudo
        ORDER BY score DESC
        LIMIT %s
        """,
        (limit,)
    )


def get_tous_genres():
    """Récupère tous les genres distincts avec identifiant et libellé."""
    return fetch_all(
        "SELECT nom_cat AS id, nom_cat AS nom FROM categorie ORDER BY nom_cat"
    )


def get_oeuvres_bibliotheque(page=1, par_page=30, filtre_type=None, filtre_genre=None, annee_min=None, annee_max=None, note_min=None, tri='populaire'):
    """Récupère les oeuvres avec pagination, filtres complets et photos"""
    decalage = (page - 1) * par_page

    clauses = []
    params_where = []
    if filtre_type:
        filtre_type_norm = str(filtre_type).strip().lower().replace('é', 'e').replace('è', 'e').replace('ê', 'e')
        clauses.append("LOWER(REPLACE(REPLACE(REPLACE(TRIM(o.type_oeuvre),'é','e'),'è','e'),'ê','e')) = %s")
        params_where.append(filtre_type_norm)
    if filtre_genre:
        if isinstance(filtre_genre, (list, tuple, set)):
            clauses.append("""
                EXISTS (
                    SELECT 1 FROM appartient AS a 
                    WHERE a.id_oeuvre = o.id_oeuvre 
                      AND a.nom_cat = ANY(%s))""")
            params_where.append(list(filtre_genre))
        else:
            clauses.append("""
                EXISTS (
                    SELECT 1 FROM appartient AS a 
                    WHERE a.id_oeuvre = o.id_oeuvre 
                      AND a.nom_cat = %s
                )
            """)
            params_where.append(filtre_genre)
    if annee_min:
        clauses.append("EXTRACT(YEAR FROM o.date_creation) >= %s")
        params_where.append(int(annee_min))
    if annee_max:
        clauses.append("EXTRACT(YEAR FROM o.date_creation) <= %s")
        params_where.append(int(annee_max))

    sql_where = f"WHERE {' AND '.join(clauses)}" if clauses else ""

    having_clauses = []
    params_having = []
    if note_min is not None:
        having_clauses.append("COALESCE(AVG(n.note), 0) >= %s")
        params_having.append(float(note_min))
    sql_having = f"HAVING {' AND '.join(having_clauses)}" if having_clauses else ""

    mapping_tri = {
        'titre': 'o.titre ASC',
        'date': 'o.date_creation DESC',
        'recent': 'o.date_creation DESC',
        'note': 'note_moyenne DESC',
        'popularite': 'nb_commentaires DESC',
        'populaire': 'nb_commentaires DESC'
    }
    sql_tri = mapping_tri.get(tri, mapping_tri['populaire']) + ", o.id_oeuvre DESC"

    base_enquete = f"""
        FROM oeuvre AS o
        LEFT JOIN commentaire AS c ON o.id_oeuvre = c.id_oeuvre
        LEFT JOIN note AS n ON o.id_oeuvre = n.id_oeuvre
        {sql_where}
        GROUP BY o.id_oeuvre, o.titre, o.date_creation, o.type_oeuvre, 
                 o.description_oeuvre, o.numero_volet_saison
        {sql_having}
    """

    requete = f"""
        SELECT o.id_oeuvre AS id, 
               o.titre, 
               o.date_creation, 
               o.type_oeuvre, 
               o.description_oeuvre, 
               o.numero_volet_saison,
               COALESCE(COUNT(DISTINCT c.id_commentaire), 0) AS nb_commentaires,
               COALESCE(AVG(n.note), 0) AS note_moyenne,
               (SELECT chemin FROM photo WHERE id_oeuvre = o.id_oeuvre LIMIT 1) AS photo
        {base_enquete}
        ORDER BY {sql_tri}
        LIMIT %s OFFSET %s
    """

    parametres = params_where + params_having + [par_page, decalage]
    oeuvres = fetch_all(requete, parametres)

    requete_comptage = f"""
        SELECT COUNT(*) AS compte FROM (
            SELECT o.id_oeuvre
            FROM oeuvre AS o
            LEFT JOIN note AS n ON o.id_oeuvre = n.id_oeuvre
            {sql_where}
            GROUP BY o.id_oeuvre
            {sql_having}
        ) AS sous
    """
    parametres_comptage = params_where + params_having
    total = fetch_one(requete_comptage, parametres_comptage if parametres_comptage else None)
    compte_total = total.compte if total else 0
    pages_total = (compte_total + par_page - 1) // par_page

    return oeuvres, pages_total, compte_total


def get_personnages_bibliotheque():
    """Liste tous les personnages avec leur nombre d'apparitions."""
    return fetch_all(
        """
        SELECT p.id_personnage, p.libelle, COUNT(DISTINCT j.id_oeuvre) AS nb_oeuvres
        FROM personnage p
        LEFT JOIN joue j ON j.id_personnage = p.id_personnage
        GROUP BY p.id_personnage, p.libelle
        ORDER BY p.libelle
        """
    )


def get_acteurs_bibliotheque():
    """Liste tous les acteurs avec le nombre d'oeuvres jouées."""
    return fetch_all(
        """
        SELECT a.id_artiste, a.nom, a.prenom, COUNT(DISTINCT j.id_oeuvre) AS nb_oeuvres
        FROM artiste a
        LEFT JOIN joue j ON j.id_artiste = a.id_artiste
        GROUP BY a.id_artiste, a.nom, a.prenom
        ORDER BY a.nom, a.prenom
        """
    )


def get_realisateurs_bibliotheque():
    """Liste tous les réalisateurs avec le nombre d'oeuvres réalisées."""
    return fetch_all(
        """
        SELECT a.id_artiste, a.nom, a.prenom, COUNT(DISTINCT r.id_oeuvre) AS nb_oeuvres
        FROM artiste a
        LEFT JOIN realise r ON r.id_artiste = a.id_artiste
        GROUP BY a.id_artiste, a.nom, a.prenom
        ORDER BY a.nom, a.prenom
        """
    )


def get_toutes_annees():
    """Récupère toutes les années de sortie distinctes"""
    return fetch_all("""
        SELECT DISTINCT EXTRACT(YEAR FROM date_creation)::int AS annee 
        FROM oeuvre 
        ORDER BY annee DESC
    """)


def get_tous_types():
    """Récupère tous les types d'oeuvres distincts"""
    return fetch_all("SELECT DISTINCT type_oeuvre FROM oeuvre ORDER BY type_oeuvre")


# ═══════════════════════════════════════════════════════════════════════════
#                          GESTION DES NOTES
# ═══════════════════════════════════════════════════════════════════════════

def ajouter_note(id_utilisateur, id_oeuvre, note):
    """
    Ajoute ou met à jour la note d'un utilisateur pour une oeuvre(1-5 étoiles)
    Si la note existe déjà, elle sera mise à jour
    """
    if note < 1 or note > 5:
        raise ValueError("La note doit être entre 1 et 5!!!!")
    
    execute(
        """
        INSERT INTO note (id_utilisateur, id_oeuvre, note, date_note)
        VALUES (%s, %s, %s, CURRENT_DATE)
        ON CONFLICT (id_utilisateur, id_oeuvre)
        DO UPDATE SET note = %s, date_note = CURRENT_DATE
        """,
        (id_utilisateur, id_oeuvre, note, note)
    )


def get_note_utilisateur(id_utilisateur, id_oeuvre):
    """
    Récupère la note donnée par un utilisateur pour une oeuvre
    Retourne None si pas de note
    """
    return fetch_one(
        "SELECT note FROM note WHERE id_utilisateur = %s AND id_oeuvre = %s",
        (id_utilisateur, id_oeuvre)
    )


def get_moyenne_note_oeuvre(id_oeuvre):
    """
    Calcule la moyenne des notes pour une oeuvre
    Retourne un tuple (moyenne, nb_votes) ou (None, 0) si pas de notes
    """
    result = fetch_one(
        """
        SELECT ROUND(AVG(note)::numeric, 1) AS moyenne, COUNT(*) AS nb_votes
        FROM note
        WHERE id_oeuvre = %s
        """,
        (id_oeuvre,)
    )
    
    if result and result.nb_votes > 0:
        return result.moyenne, result.nb_votes
    return None, 0


def supprimer_note(id_utilisateur, id_oeuvre):
    """Supprime la note d'un utilisateur pour une oeuvre"""
    execute(
        "DELETE FROM note WHERE id_utilisateur = %s AND id_oeuvre = %s",
        (id_utilisateur, id_oeuvre)
    )


def get_top_oeuvres(limit=20):
    """
    Récupère les meilleures oeuvres selon leurs notes
    Utilise la vue top_oeuvres
    """
    return fetch_all(
        f"SELECT * FROM top_oeuvres LIMIT {limit}"
    )


def get_top_oeuvres_par_periode(periode="jour", limit=7):
    """
    Récupère les oeuvres les mieux notées sur une période donnée.
    periode: 'jour', 'semaine', 'mois'
    """
    mapping = {
        "jour": "1 day",
        "day": "1 day",
        "semaine": "7 days",
        "week": "7 days",
        "mois": "30 days",
        "month": "30 days"
    }
    interval = mapping.get(periode, "30 days")
    resultats = fetch_all(
        """
        SELECT 
            o.*,
            COALESCE(AVG(n.note), 0) AS note_moyenne,
            COUNT(n.id_utilisateur) AS nb_votes
        FROM oeuvre AS o
        JOIN note AS n ON n.id_oeuvre = o.id_oeuvre
        WHERE n.date_note >= CURRENT_DATE - %s::interval
        GROUP BY o.id_oeuvre, o.titre, o.type_oeuvre, o.date_creation, o.description_oeuvre, o.numero_volet_saison
        ORDER BY note_moyenne DESC, nb_votes DESC, o.id_oeuvre DESC
        LIMIT %s
        """,
        (interval, limit)
    )
    if len(resultats) >= limit:
        return resultats
    deja = {r.id_oeuvre for r in resultats}
    complement = []
    for o in get_top_oeuvres(limit * 2):
        if o.id_oeuvre not in deja:
            complement.append(o)
            deja.add(o.id_oeuvre)
        if len(resultats) + len(complement) >= limit:
            break
    return list(resultats) + complement


def get_notes_utilisateur(id_utilisateur):
    """Récupère toutes les notes données par un utilisateur"""
    return fetch_all(
        """
        SELECT n.*, o.titre, o.type_oeuvre
        FROM note n
        JOIN oeuvre o ON n.id_oeuvre = o.id_oeuvre
        WHERE n.id_utilisateur = %s
        ORDER BY n.date_note DESC
        """,
        (id_utilisateur,)
    )


# ═══════════════════════════════════════════════════════════════════════════
#                    GESTION DES NOTES DE COMMENTAIRES
# ═══════════════════════════════════════════════════════════════════════════

def noter_commentaire(id_utilisateur, id_commentaire, utile):
    """
    Ajoute ou met à jour le vote d'utilité d'un commentaire
    utile: True = utile, False = pas utile
    """
    execute(
        """
        INSERT INTO note_commentaire (id_utilisateur, id_commentaire, utile)
        VALUES (%s, %s, %s)
        ON CONFLICT (id_utilisateur, id_commentaire)
        DO UPDATE SET utile = %s
        """,
        (id_utilisateur, id_commentaire, utile, utile)
    )


def get_vote_commentaire_utilisateur(id_utilisateur, id_commentaire):
    """
    Vérifie si l'utilisateur a voté sur ce commentaire
    Retourne True, False ou None
    """
    result = fetch_one(
        "SELECT utile FROM note_commentaire WHERE id_utilisateur = %s AND id_commentaire = %s",
        (id_utilisateur, id_commentaire)
    )
    return result.utile if result else None


def get_commentaires_avec_votes(id_oeuvre):
    """
    Récupère tous les commentaires d'une oeuvre avec leurs statistiques de votes
    Utilise la vue commentaires_avec_utilite
    """
    return fetch_all(
        """
        SELECT * FROM commentaires_avec_utilite
        WHERE id_oeuvre = %s
        ORDER BY nb_utiles DESC, date_commentaire DESC
        """,
        (id_oeuvre,)
    )


def supprimer_vote_commentaire(id_utilisateur, id_commentaire):
    """Supprime le vote d'un utilisateur sur un commentaire"""
    execute(
        "DELETE FROM note_commentaire WHERE id_utilisateur = %s AND id_commentaire = %s",
        (id_utilisateur, id_commentaire)
    )

# ═══════════════════════════════════════════════════════════════════════════
#                              FIN DU FICHIER 
# ═══════════════════════════════════════════════════════════════════════════
