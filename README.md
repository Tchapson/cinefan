# CinéFan

Application web de catalogue cinéma développée avec Flask et PostgreSQL.

Les utilisateurs peuvent parcourir des œuvres et des artistes, laisser des commentaires,
gérer leurs favoris et créer un compte personnel.

## Fonctionnalités

- Catalogue d'œuvres (films, séries) avec pages détail et affiche visuelle
- Catalogue d'artistes (réalisateurs, acteurs) avec filmographie
- Recherche full-text sur les titres et descriptions
- Inscription et connexion avec mot de passe haché (bcrypt)
- Système de favoris par utilisateur
- Commentaires sur les œuvres
- Page profil utilisateur (nb de favoris, nb de commentaires)
- Middleware de protection des routes (accès restreint sans connexion)
- Grille visuelle de films sur la page d'accueil avec badges genre/type
- Page 404 personnalisée

## Technologies

- **Backend :** Python 3, Flask
- **Base de données :** PostgreSQL (via psycopg2)
- **Sécurité :** bcrypt pour le hachage des mots de passe, sessions Flask
- **Frontend :** HTML/CSS (Jinja2)

## Installation

### Prérequis

- Python 3.x
- PostgreSQL

### Étapes

1. Cloner le dépôt :

```bash
git clone https://github.com/TON_USERNAME/cinefan-flask.git
cd cinefan-flask
```

2. Installer les dépendances :

```bash
pip install -r requirements.txt
```

3. Configurer la base de données :

```bash
cp .env.example .env
# Éditer .env avec vos identifiants PostgreSQL
```

4. Importer le schéma, les données de base, puis l'enrichissement :

```bash
psql -U postgres -d cinefan -f dump.sql
psql -U postgres -d cinefan -f data_enrichissement.sql
```

5. Lancer l'application :

```bash
python3 main.py
```

L'application est accessible sur `http://localhost:5000`.

## Structure du projet

```
cinefan-flask/
├── main.py               # Application Flask — routes et logique
├── db.py                 # Connexion PostgreSQL et fonctions d'accès aux données
├── dump.sql              # Schéma et données de la base
├── requirements.txt      # Dépendances Python
├── .env.example          # Modèle de configuration (à copier en .env)
├── static/
│   └── style.css         # Feuille de style
└── templates/            # Templates Jinja2
    ├── accueil.html
    ├── oeuvres.html
    ├── oeuvre_detail.html
    ├── artistes.html
    ├── artiste_detail.html
    ├── connexion.html
    ├── inscription.html
    ├── profil.html
    ├── favoris.html
    ├── recherche.html
    └── 404.html
```

## Compétences mises en œuvre

- Développement web backend avec Flask
- Modélisation et requêtes SQL (PostgreSQL)
- Authentification sécurisée (hachage bcrypt, sessions)
- Architecture MVC légère (routes / accès données / templates)
- Gestion des variables d'environnement

## Auteur

Mohamed Fane — L2 Informatique
