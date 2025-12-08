from flask import Flask, render_template, request, redirect, url_for, session, flash
from datetime import date
from db import (
    fetch_all,
    fetch_one,
    execute,
    creer_utilisateur,
    verifier_utilisateur,
    get_utilisateur_par_email
)

app = Flask(__name__)
app.secret_key = "CHANGE_THIS_SECRET_KEY"


# ---------------------------------------------------------
# ROUTES : ACCUEIL
# ---------------------------------------------------------
@app.route("/")
def accueil():
    nb_oeuvres = fetch_one("SELECT COUNT(*) AS c FROM oeuvre").c
    nb_artistes = fetch_one("SELECT COUNT(*) AS c FROM artiste").c
    nb_commentaires = fetch_one("SELECT COUNT(*) AS c FROM commentaire").c

    oeuvres_recent = fetch_all("""
        SELECT id_oeuvre, titre, type_oeuvre, date_creation
        FROM oeuvre
        ORDER BY id_oeuvre DESC
        LIMIT 6
    """)

    return render_template(
        "accueil.html",
        nb_oeuvres=nb_oeuvres,
        nb_artistes=nb_artistes,
        nb_commentaires=nb_commentaires,
        oeuvres_recent=oeuvres_recent
    )


# ---------------------------------------------------------
# ROUTES : RECHERCHE
# ---------------------------------------------------------
@app.route("/recherche")
def recherche():
    q = request.args.get("q", "")

    if q.strip() == "":
        return render_template("recherche.html", q="", resultats=[])

    resultats = fetch_all("""
        SELECT id_oeuvre, titre, type_oeuvre, date_creation
        FROM oeuvre
        WHERE LOWER(titre) LIKE LOWER(%s)
           OR LOWER(description_oeuvre) LIKE LOWER(%s)
        ORDER BY titre
    """, (f"%{q}%", f"%{q}%"))

    return render_template("recherche.html", q=q, resultats=resultats)


# ---------------------------------------------------------
# ROUTES : LISTE DES ŒUVRES
# ---------------------------------------------------------
@app.route("/oeuvres")
def oeuvres():
    data = fetch_all("""
        SELECT id_oeuvre, titre, type_oeuvre, date_creation
        FROM oeuvre
        ORDER BY titre
    """)

    return render_template("oeuvres.html", oeuvres=data)


# ---------------------------------------------------------
# ROUTES : DÉTAIL D’UNE ŒUVRE
# ---------------------------------------------------------
@app.route("/oeuvre/<int:id_oeuvre>")
def oeuvre_detail(id_oeuvre):
    oeuvre = fetch_one("""
        SELECT *
        FROM oeuvre
        WHERE id_oeuvre = %s
    """, (id_oeuvre,))

    if not oeuvre:
        return render_template("404.html"), 404

    genres = fetch_all("""
        SELECT nom_cat
        FROM appartient
        WHERE id_oeuvre = %s
    """, (id_oeuvre,))

    realisateurs = fetch_all("""
        SELECT artiste.id_artiste, prenom, nom
        FROM realise
        JOIN artiste ON artiste.id_artiste = realise.id_artiste
        WHERE realise.id_oeuvre = %s
    """, (id_oeuvre,))

    acteurs = fetch_all("""
        SELECT a.id_artiste, a.prenom, a.nom, p.libelle AS personnage
        FROM joue j
        JOIN artiste a ON a.id_artiste = j.id_artiste
        JOIN personnage p ON p.id_personnage = j.id_personnage
        WHERE j.id_oeuvre = %s
    """, (id_oeuvre,))

    liens = fetch_all("""
        SELECT o2.id_oeuvre AS id_liee, o2.titre, l.type_lien
        FROM lien l
        JOIN oeuvre o2 ON o2.id_oeuvre = l.id_oeuvre2
        WHERE l.id_oeuvre1 = %s
    """, (id_oeuvre,))

    commentaires = fetch_all("""
        SELECT c.*, u.pseudo
        FROM commentaire c
        JOIN utilisateur u ON u.id_utilisateur = c.id_utilisateur
        WHERE c.id_oeuvre = %s
        ORDER BY c.date_commentaire DESC
    """, (id_oeuvre,))

    est_favori = False
    if session.get("user_id"):
        fav = fetch_one("""
            SELECT 1 FROM favoris
            WHERE id_utilisateur = %s AND id_oeuvre = %s
        """, (session["user_id"], id_oeuvre))
        est_favori = bool(fav)

    return render_template(
        "oeuvre_detail.html",
        oeuvre=oeuvre,
        genres=genres,
        realisateurs=realisateurs,
        acteurs=acteurs,
        liens=liens,
        commentaires=commentaires,
        est_favori=est_favori
    )


# ---------------------------------------------------------
# FAVORIS
# ---------------------------------------------------------
@app.route("/favori/<int:id_oeuvre>", methods=["POST"])
def ajouter_favori(id_oeuvre):
    if "user_id" not in session:
        return redirect(url_for("connexion"))

    execute("""
        INSERT INTO favoris(id_utilisateur, id_oeuvre, date_ajout)
        VALUES (%s, %s, %s)
        ON CONFLICT DO NOTHING
    """, (session["user_id"], id_oeuvre, date.today()))

    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))


# ---------------------------------------------------------
# COMMENTAIRES
# ---------------------------------------------------------
@app.route("/commentaire/<int:id_oeuvre>", methods=["POST"])
def ajouter_commentaire(id_oeuvre):
    if "user_id" not in session:
        return redirect(url_for("connexion"))

    contenu = request.form.get("contenu")

    execute("""
        INSERT INTO commentaire(contenu, date_commentaire, id_utilisateur, id_oeuvre)
        VALUES (%s, %s, %s, %s)
    """, (contenu, date.today(), session["user_id"], id_oeuvre))

    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))


# ---------------------------------------------------------
# INSCRIPTION
# ---------------------------------------------------------
@app.route("/inscription", methods=["GET", "POST"])
def inscription():
    if request.method == "POST":
        pseudo = request.form.get("pseudo")
        email = request.form.get("email")
        mdp = request.form.get("mdp")

        if get_utilisateur_par_email(email):
            flash("Email déjà utilisé.", "error")
            return redirect(url_for("inscription"))

        creer_utilisateur(pseudo, email, mdp)
        flash("Compte créé avec succès !", "success")
        return redirect(url_for("connexion"))

    return render_template("inscription.html")


# ---------------------------------------------------------
# CONNEXION
# ---------------------------------------------------------
@app.route("/connexion", methods=["GET", "POST"])
def connexion():
    if request.method == "POST":
        email = request.form.get("email")
        mdp = request.form.get("mdp")

        user = verifier_utilisateur(email, mdp)

        if not user:
            flash("Identifiants incorrects.", "error")
            return redirect(url_for("connexion"))

        session["user_id"] = user.id_utilisateur
        session["pseudo"] = user.pseudo

        return redirect(url_for("accueil"))

    return render_template("connexion.html")


# ---------------------------------------------------------
# DÉCONNEXION
# ---------------------------------------------------------
@app.route("/deconnexion")
def deconnexion():
    session.clear()
    return redirect(url_for("accueil"))


# ---------------------------------------------------------
# ERREUR 404
# ---------------------------------------------------------
@app.errorhandler(404)
def page_404(e):
    return render_template("404.html"), 404

@app.route("/accueil")
def accueil_redirect():
    return redirect(url_for("accueil"))

# ---------------------------------------------------------
# LANCEMENT SERVEUR
# ---------------------------------------------------------
if __name__ == "__main__":
    app.run(debug=True)
