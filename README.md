# CinéFan

Application de catalogue de films et séries réalisée en équipe dans le cadre de la licence informatique. Backend Python/Flask, base PostgreSQL et interface HTML/CSS avec Jinja2.

## Fonctionnalités

- Catalogue avec fiches d'œuvres, filtres, recherche et pagination.
- Inscription, connexion et sessions ; hachage des mots de passe avec Werkzeug.
- Favoris, notes, commentaires et profil utilisateur.
- Statistiques et interface d'administration réservée aux administrateurs.

## Installation locale

Prérequis : Python 3, PostgreSQL en cours d'exécution, outils `psql` et `createdb`, Git.

```bash
git clone https://github.com/Tchapson/cinefan.git
cd cinefan
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
python -c "import secrets; print(secrets.token_hex(32))"
```

Renseigner `.env` : `DB_NAME`, `DB_USER`, `DB_HOST`, `DB_PASSWORD`, `DB_PORT` et la valeur générée pour `SECRET_KEY`. Ne pas publier ce fichier. Sous Windows, activer l'environnement avec `.venv\Scripts\activate`.

Créer une **base locale dédiée et vide**. Adapter l'utilisateur, le port et le nom de base ci-dessous aux valeurs de `.env` (les outils PostgreSQL ne lisent pas ce fichier automatiquement) :

```bash
createdb -h localhost -p 5432 -U postgres cinefan
psql -h localhost -p 5432 -U postgres -d cinefan -v ON_ERROR_STOP=1 -f dump.sql
psql -h localhost -p 5432 -U postgres -d cinefan -v ON_ERROR_STOP=1 -f data_enrichissement.sql
python main.py
```

Ouvrir http://127.0.0.1:5000. **`dump.sql` supprime et recrée les tables concernées : ne pas l'exécuter sur une base contenant des données à conserver.**

## Parcours de démonstration

1. Parcourir le catalogue et tester les filtres.
2. Créer un compte depuis l'inscription, puis se connecter.
3. Ajouter un favori, une note et un commentaire ; consulter le profil.
4. L'administration nécessite un compte disposant du rôle administrateur en base.

## Structure

- `main.py` : routes Flask, sessions, validation des requêtes et rendu.
- `fonctions.py` : accès aux données et opérations métier.
- `db.py` : connexion PostgreSQL configurée par environnement.
- `templates/`, `static/` : vues, CSS et images.
- `dump.sql`, `data_enrichissement.sql` : initialisation et données de démonstration.

## Périmètre et limites

Projet pédagogique à exécuter localement. La configuration de production, la protection CSRF, les limites de téléversement et l'audit complet des droits restent à traiter avant une exposition publique. Une clé de session temporaire est générée si `SECRET_KEY` est vide : les sessions expirent alors au redémarrage.

Les anciens comptes du jeu de données ne sont pas des identifiants de démonstration garantis : créer un compte dédié. Les modifications des secrets doivent être faites aussi sur les services concernés ; modifier un fichier Git ne révoque pas les anciennes valeurs.

Mohamed Noumory Fané — licence informatique.
