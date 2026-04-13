"""
═══════════════════════════════════════════════════════════════════════════
    APP WEB FLASK - PROJET CINEFAN
═══════════════════════════════════════════════════════════════════════════
    
    Application web pour gérer une collection d'oeuvres cinématographiques
    
    Routes principales:
    - /: page d'accueil avec statistiques
    - /oeuvres: liste de toutes les oeuvres
    - /oeuvre/<id>: détail d'une oeuvre
    - /recherche: recherche d'oeuvres
    - /connexion, /inscription: authentification
    - /admin: panneau d'administration(réservé aux admins)
    - /statistiques: page de statistiques globales
    - /autres routes pour gestion des favoris, notes, commentaires, etc...
═══════════════════════════════════════════════════════════════════════════
"""

from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from werkzeug.utils import secure_filename
from pathlib import Path
from dotenv import load_dotenv
import os
import fonctions as fcts

load_dotenv(Path(__file__).resolve().parent / ".env")

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-key-change-in-production")




# ═══════════════════════════════════════════════════════════════════════════
#                           ROUTES: ACCUEIL
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/")
def accueil():
    """
    Page d'accueil: affiche des stats globales et les oeuvres récentes
    """
    nb_oeuvres = fcts.compter_lignes("oeuvre").c
    nb_artistes = fcts.compter_lignes("artiste").c
    nb_commentaires = fcts.compter_lignes("commentaire").c
    oeuvres_recent = fcts.get_oeuvres_avec_photos(30)

    def _map_with_photos(raw_list):
        photos = fcts.get_photos_oeuvres(raw_list)
        mapped = []
        for o in raw_list:
            photo = photos.get(o.id_oeuvre) if photos else None
            if photo and not str(photo).startswith(("http://", "https://", "/")):
                photo = url_for("static", filename=photo)
            mapped.append({
                "id_oeuvre": o.id_oeuvre,
                "titre": getattr(o, "titre", ""),
                "type_oeuvre": getattr(o, "type_oeuvre", ""),
                "date_creation": getattr(o, "date_creation", None),
                "note_moyenne": getattr(o, "note_moyenne", None),
                "photo": photo
            })
        return mapped

    top_jour_raw = fcts.get_top_oeuvres_par_periode("jour", 7)
    top_semaine_raw = fcts.get_top_oeuvres_par_periode("semaine", 7)
    top_mois_raw = fcts.get_top_oeuvres_par_periode("mois", 7)
    top_jour = _map_with_photos(top_jour_raw)
    top_semaine = _map_with_photos(top_semaine_raw)
    top_mois = _map_with_photos(top_mois_raw)
    top_users = fcts.get_top_utilisateurs(5)

    return render_template(
        "accueil.html",
        nb_oeuvres=nb_oeuvres,
        nb_artistes=nb_artistes,
        nb_commentaires=nb_commentaires,
        oeuvres_recent=oeuvres_recent,
        top_users=top_users,
        top_jour=top_jour,
        top_semaine=top_semaine,
        top_mois=top_mois
    )


# ═══════════════════════════════════════════════════════════════════════════
#                           ROUTES: RECHERCHE
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/recherche")
def recherche():
    """
    Recherche d'oeuvres par titre ou description
    Si pas de query, affiche la page vide
    """
    q = request.args.get("q", "")
    type_filtre = request.args.get("type")
    wants_json = request.args.get("format") == "json" or "application/json" in request.headers.get("Accept", "")

    if q == "":
        if wants_json:
            return jsonify([])
        return render_template("recherche.html", q="", resultats=[])

    def _norm_type(val):
        if not val:
            return ""
        return str(val).lower()

    oeuvres = fcts.rechercher_oeuvres(q)
    photos = fcts.get_photos_oeuvres(oeuvres)
    utilisateurs = []

    if type_filtre:
        tf = _norm_type(type_filtre)
        if tf in ["film", "serie", "anime"]:
            oeuvres = [o for o in oeuvres if _norm_type(getattr(o, "type_oeuvre", "")) == tf]
        elif tf == "utilisateur":
            oeuvres = []
            utilisateurs = fcts.rechercher_utilisateurs(q)
        else:
            oeuvres = []
            utilisateurs = []

    if wants_json:
        data = []
        for o in oeuvres:
            photo = photos.get(o.id_oeuvre)
            if photo and not str(photo).startswith(("http://", "https://", "/")):
                photo = url_for("static", filename=photo)
            date_creation = getattr(o, "date_creation", None)
            if date_creation:
                try:
                    date_creation = date_creation.strftime("%Y")
                except Exception:
                    date_creation = str(date_creation)
            data.append({
                "id": o.id_oeuvre,
                "titre": o.titre,
                "type_oeuvre": o.type_oeuvre,
                "date_creation": date_creation,
                "photo": photo,
                "url": url_for("oeuvre_detail", id_oeuvre=o.id_oeuvre)
            })
        for u in utilisateurs:
            data.append({
                "id": getattr(u, "id_utilisateur", None),
                "titre": getattr(u, "pseudo", ""),
                "type": "utilisateur",
                "date_creation": getattr(u, "email", ""),
                "photo": None,
                "url": "#"
            })
        return jsonify(data)

    return render_template("recherche.html", q=q, resultats=oeuvres)


# ═══════════════════════════════════════════════════════════════════════════
#                      ROUTES: LISTE DES OEUVRES
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/oeuvres")
def oeuvres():
    """Liste complète de toutes les oeuvres avec filtres et pagination"""
    page = request.args.get('page', 1, type=int)
    raw_type = request.args.get('type', None)
    filtre_type = raw_type
    filtre_genres = [g for g in request.args.getlist('genre') if g not in (None, '', [])]
    annee_min = request.args.get('annee_min', type=int)
    annee_max = request.args.get('annee_max', type=int)
    note_min = request.args.get('note_min', type=float)
    tri = request.args.get('tri', 'populaire')
    wants_json = request.args.get('format') == 'json' or "application/json" in request.headers.get("Accept", "")
    
    data, total_pages, total_count = fcts.get_oeuvres_bibliotheque(
        page=page, par_page=30, 
        filtre_type=filtre_type, 
        filtre_genre=filtre_genres, 
        annee_min=annee_min,
        annee_max=annee_max,
        note_min=note_min,
        tri=tri
    )

    def _map_oeuvre(o):
        photo = fcts.normalize_photo(getattr(o, "photo", None))
        return {
            "id": getattr(o, "id", None),
            "id_oeuvre": getattr(o, "id_oeuvre", None),
            "titre": getattr(o, "titre", ""),
            "type_oeuvre": getattr(o, "type_oeuvre", ""),
            "date_creation": getattr(o, "date_creation", None),
            "annee_sortie": getattr(o, "annee_sortie", None),
            "photo": photo,
        }

    display_data = [_map_oeuvre(o) for o in data]
    
    genres = fcts.get_tous_genres()
    annees = fcts.get_toutes_annees()
    types = fcts.get_tous_types()
    personnages = fcts.get_personnages_bibliotheque()
    acteurs = fcts.get_acteurs_bibliotheque()
    realisateurs = fcts.get_realisateurs_bibliotheque()

    people_items = []
    for p in personnages:
        try:
            libelle = p.libelle
        except AttributeError:
            libelle = "Personnage"
        try:
            nb_oeuvres = p.nb_oeuvres
        except AttributeError:
            nb_oeuvres = 0
            
        people_items.append({
            "type": "personnage",
            "nom": libelle,
            "meta": f"{nb_oeuvres} oeuvre(s)"
        })
    for a in acteurs:
        prenom = getattr(a, "prenom", None)
        nom = getattr(a, "nom", None)
        if prenom and nom:
            nom_complet = prenom + " " + nom
        elif prenom:
            nom_complet = prenom
        elif nom:
            nom_complet = nom
        else:
            nom_complet = "Acteur"
        people_items.append({
            "type": "acteur",
            "nom": nom_complet,
            "meta": f"{getattr(a, 'nb_oeuvres', 0)} oeuvre(s)"
        })
    for r in realisateurs:
        prenom = getattr(r, "prenom", None)
        nom = getattr(r, "nom", None)
        if prenom and nom:
            nom_complet = prenom + " " + nom
        elif prenom:
            nom_complet = prenom
        elif nom:
            nom_complet = nom
        else:
            nom_complet = "Réalisateur"
        people_items.append({
            "type": "realisateur",
            "nom": nom_complet,
            "meta": f"{getattr(r, 'nb_oeuvres', 0)} oeuvre(s)"
        })
    
    base_params = {
        "type": raw_type,
        "annee_min": annee_min,
        "annee_max": annee_max,
        "note_min": note_min,
        "tri": tri
    }
    if filtre_genres:
        base_params["genre"] = filtre_genres
    base_params = {k: v for k, v in base_params.items() if v not in (None, "", [])}

    if wants_json:
        cards_html = render_template("partiels/oeuvre_cards.html", oeuvres=display_data)
        pagination_html = render_template(
            "partiels/pagination.html",
            page=page,
            total_pages=total_pages,
            base_params=base_params
        ) if total_pages > 1 else ""
        return jsonify({
            "html": cards_html,
            "pagination": pagination_html,
            "count": total_count
        })
    
    return render_template("oeuvres.html", 
        oeuvres=display_data, 
        genres=genres, 
        annees=annees,
        types=types,
        people_items=people_items,
        page=page, 
        total_pages=total_pages,
        total_count=total_count,
        current_type=raw_type,
        current_genres=filtre_genres,
        annee_min=annee_min,
        annee_max=annee_max,
        current_tri=tri,
        current_note=note_min,
        base_params=base_params
    )

@app.route("/statistiques")
def statistiques():
    """Page des statistiques globales"""
    stats = fcts.get_stats_generales()
    stats_users = fcts.get_stats_utilisateurs()
    top_raw = fcts.get_top_oeuvres(10)
    top_photos = fcts.get_photos_oeuvres(top_raw)
    top_oeuvres = []
    for o in top_raw:
        photo = top_photos.get(o.id_oeuvre) if top_photos else None
        if photo and not str(photo).startswith(("http://", "https://", "/")):
            photo = url_for("static", filename=photo)
        try:
            note_moyenne = o.note_moyenne
        except AttributeError:
            note_moyenne = None
        top_oeuvres.append({
            "id": o.id_oeuvre,
            "titre": o.titre,
            "type": o.type_oeuvre,
            "note": note_moyenne,
            "photo": photo
        })

    top_commentes = fcts.get_top_oeuvres_commentees(10)
    top_commentes_fmt = []
    photos_com = fcts.get_photos_oeuvres(top_commentes)
    for o in top_commentes:
        photo = photos_com.get(o.id_oeuvre) if photos_com else None
        if photo and not str(photo).startswith(("http://", "https://", "/")):
            photo = url_for("static", filename=photo)
        top_commentes_fmt.append({
            "id": o.id_oeuvre,
            "titre": o.titre,
            "type": o.type_oeuvre,
            "nb_commentaires": o.nb_commentaires,
            "photo": photo
        })

    rc_page = request.args.get("rc_page", 1, type=int)
    rc_par_page = 5
    rc_offset = (rc_page - 1) * rc_par_page
    total_comments = fcts.compter_lignes("commentaire").c if stats else 0
    rc_pages = max(1, (total_comments + rc_par_page - 1) // rc_par_page)
    recent_comments = fcts.get_commentaires_recents(5)
    genres_raw = fcts.get_moyenne_commentaires_genre()
    gs_page = request.args.get("gs_page", 1, type=int)
    gs_par_page = 5
    gs_total = len(genres_raw) if genres_raw else 0
    gs_pages = max(1, (gs_total + gs_par_page - 1) // gs_par_page)
    start = (gs_page - 1) * gs_par_page
    genres_stats = genres_raw[start:start+gs_par_page] if genres_raw else []

    user_stats = None
    if session.get("user_id"):
        favs = fcts.get_favoris_utilisateur(session["user_id"])
        notes = fcts.get_notes_utilisateur(session["user_id"])
        user = fcts.get_utilisateur_par_id(session["user_id"])
        user_pseudo = user.pseudo if user else None
        user_stats = {
            "pseudo": user_pseudo,
            "favoris": len(favs),
            "notes": len(notes),
            "derniere_note": notes[0] if notes else None
        }

    return render_template("statistiques.html",
        stats=stats,
        stats_users=stats_users,
        top_oeuvres=top_oeuvres,
        top_commentes=top_commentes_fmt,
        recent_comments=recent_comments,
        rc_page=rc_page,
        rc_pages=rc_pages,
        gs_page=gs_page,
        gs_pages=gs_pages,
        genres_stats=genres_stats,
        user_stats=user_stats
    )


@app.route("/admin")
def admin_panel():
    """Tableau de bord admin"""
    admin_user = fcts.get_admin_user(session["user_id"])
    if not admin_user:
        return redirect(url_for("connexion"))

    stats = fcts.get_stats_generales()
    stats_users = fcts.get_stats_utilisateurs()
    recent_comments = fcts.get_commentaires_recents(5)
    user_stats = None
    favs = fcts.get_favoris_utilisateur(session["user_id"])
    notes = fcts.get_notes_utilisateur(session["user_id"])
    user_pseudo = None
    if session.get("user_id"):
        user = fcts.get_utilisateur_par_id(session["user_id"])
        user_pseudo = user.pseudo if user else None
    user_stats = {
        "pseudo": user_pseudo,
        "favoris": len(favs),
        "notes": len(notes),
        "derniere_note": notes[0] if notes else None
    }

    q = request.args.get("q", "")
    page = request.args.get("page", 1, type=int)
    par_page = 5
    offset = (page - 1) * par_page
    params = []
    where = ""
    if q:
        where = "WHERE c.commentaire ILIKE %s"
        params.append(f"%{q}%")
    count_row = fcts.get_count_commentaires_admin(where, params)
    total = count_row.c if count_row else 0
    total_pages = max(1, (total + par_page - 1) // par_page)
    msg_rows = fcts.get_commentaires_page_admin(where, params, par_page, offset)

    if request.args.get("partial") == "comments":
        return render_template(
            "partiels/admin_comments.html",
            messages=msg_rows,
            q=q,
            page=page,
            total_pages=total_pages
        )

    search_user = request.args.get("user_search", "")
    users_found = []
    categories = fcts.get_toutes_categories()
    oeuvres_all = fcts.get_toutes_oeuvres()
    if search_user:
        users_found = fcts.rechercher_utilisateurs(search_user)

    return render_template("pannel_admin.html",
        stats=stats,
        stats_users=stats_users,
        recent_comments=recent_comments,
        user_stats=user_stats,
        messages=msg_rows,
        q=q,
        page=page,
        total_pages=total_pages,
        search_user=search_user,
        users_found=users_found,
        categories=categories,
        oeuvres_all=oeuvres_all
    )


@app.route("/admin/user/<int:id_utilisateur>/ban", methods=["POST"])
def admin_ban_user(id_utilisateur):
    admin_user = fcts.get_admin_user(id_utilisateur)
    if not admin_user:
        return redirect(url_for("connexion"))
    fcts.bannir_utilisateur(id_utilisateur)
    return redirect(url_for("admin_panel"))


@app.route("/admin/user/<int:id_utilisateur>/unban", methods=["POST"])
def admin_unban_user(id_utilisateur):
    admin_user = fcts.get_admin_user(id_utilisateur)
    if not admin_user:
        return redirect(url_for("connexion"))
    fcts.debannir_utilisateur(id_utilisateur)
    return redirect(url_for("admin_panel"))


@app.route("/admin/comment/<int:id_commentaire>/delete", methods=["POST"])
def admin_delete_comment(id_commentaire):
    admin_user = fcts.get_admin_user(session["user_id"])
    if not admin_user:
        return redirect(url_for("connexion"))
    fcts.supprimer_commentaire(id_commentaire)
    return redirect(url_for("admin_panel"))


@app.route("/admin/comment/<int:id_commentaire>/ban_delete", methods=["POST"])
def admin_ban_delete_comment(id_commentaire):
    admin_user = fcts.get_admin_user(session["user_id"])
    if not admin_user:
        return redirect(url_for("connexion"))
    id_utilisateur = request.form.get("id_utilisateur")
    if id_utilisateur:
        fcts.bannir_utilisateur(id_utilisateur)
    fcts.supprimer_commentaire(id_commentaire)
    return redirect(url_for("admin_panel"))


@app.route("/admin/oeuvre/new", methods=["POST"])
def admin_oeuvre_new():
    admin_user = fcts.get_admin_user(session["user_id"])
    if not admin_user:
        return redirect(url_for("connexion"))
    titre = request.form.get("titre")
    type_oeuvre = request.form.get("type_oeuvre")
    date_creation = request.form.get("date_creation")
    description = request.form.get("description")
    numero_raw = request.form.get("numero_volet_saison") or None

    numero = int(numero_raw) if numero_raw else None
    photo_file = request.files.get("photo_file")
    genres = request.form.getlist("genres")
    lien_oeuvre = request.form.get("lien_oeuvre")
    lien_type = request.form.get("lien_type")

    new_id = fcts.creer_oeuvre(titre, type_oeuvre, date_creation, description, numero)
    if new_id:
        if photo_file and photo_file.filename:
            upload_dir = f"{app.root_path}/static/images/"
            os.makedirs(upload_dir, exist_ok=True)
            filename = secure_filename(photo_file.filename)
            save_path = f"{upload_dir}/{filename}"
            photo_file.save(save_path)
            rel_path = f"static/images/{filename}"
            fcts.ajouter_photo_oeuvre(new_id, rel_path)
        for g in genres:
            fcts.ajouter_genre_oeuvre(new_id, g)

        if lien_oeuvre and lien_type:
            fcts.ajouter_lien_oeuvre(new_id, int(lien_oeuvre), lien_type)

    return redirect(url_for("admin_panel"))

@app.route("/admin/oeuvre/edit", methods=["POST"])
def admin_oeuvre_edit():
    admin_user = fcts.get_admin_user(session["user_id"])
    if not admin_user:
        return redirect(url_for("connexion"))

    id_oeuvre = int(request.form.get("id_oeuvre"))
    titre = request.form.get("titre") or None
    type_oeuvre = request.form.get("type_oeuvre") or None
    date_creation = request.form.get("date_creation") or None
    description = request.form.get("description") or None
    numero_raw = request.form.get("numero_volet_saison") or None
    numero = int(numero_raw) if numero_raw else None

    photo_file = request.files.get("photo_file")

    fcts.update_oeuvre(
        id_oeuvre,
        titre=titre,
        type_oeuvre=type_oeuvre,
        date_creation=date_creation,
        description_oeuvre=description,
        numero_volet_saison=numero
    )

    if photo_file and photo_file.filename:
        upload_dir = f"{app.root_path}/static/images"
        os.makedirs(upload_dir, exist_ok=True)
        filename = secure_filename(photo_file.filename)
        save_path = f"{upload_dir}/{filename}"
        photo_file.save(save_path)
        rel_path = f"static/images/{filename}"
        fcts.remplacer_photo_oeuvre(id_oeuvre, rel_path)

    return redirect(url_for("admin_panel"))


@app.route("/admin/oeuvre/delete", methods=["POST"])
def admin_oeuvre_delete():
    admin_user = fcts.get_admin_user()
    if not admin_user:
        return redirect(url_for("connexion"))
    id_oeuvre = request.form.get("id_oeuvre")
    if id_oeuvre:
        try:
            fcts.supprimer_oeuvre(int(id_oeuvre))
        except Exception:
            pass
    return redirect(url_for("admin_panel"))


# ═══════════════════════════════════════════════════════════════════════════
#                      ROUTES: DÉTAIL D'UNE OEUVRE
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/oeuvre/<int:id_oeuvre>")
def oeuvre_detail(id_oeuvre):
    """
    Page de détail d'une oeuvre: infos, genres, acteurs, réalisateurs,
    commentaires, liens vers autres oeuvres, statut favori, notes
    """
    if not fcts.oeuvre_existe(id_oeuvre):
        return render_template("404.html"), 404
    
    oeuvre = fcts.get_oeuvre(id_oeuvre)
    genres = fcts.get_genres_oeuvre(id_oeuvre)
    realisateurs = fcts.get_realisateurs_oeuvre(id_oeuvre)
    acteurs = fcts.get_personnages_avec_acteurs(id_oeuvre)
    liens = fcts.get_liens_oeuvre(id_oeuvre)
    commentaires_full = fcts.get_commentaires_avec_votes(id_oeuvre)
    c_page = request.args.get("cpage", 1, type=int)
    c_par_page = 5
    c_total = len(commentaires_full) if commentaires_full else 0
    c_pages = max(1, (c_total + c_par_page - 1) // c_par_page)
    c_page = min(max(c_page, 1), c_pages)
    c_start = (c_page - 1) * c_par_page
    commentaires = commentaires_full[c_start:c_start + c_par_page] if commentaires_full else []
    
    moyenne, nb_votes = fcts.get_moyenne_note_oeuvre(id_oeuvre)
    oeuvre_est_favori = False
    note_utilisateur = None
    votes_utilisateur = {}
    
    if session.get("user_id"):
        oeuvre_est_favori = fcts.est_favori(session["user_id"], id_oeuvre)
        note_result = fcts.get_note_utilisateur(session["user_id"], id_oeuvre)
        note_utilisateur = note_result.note if note_result else None
        
        for c in commentaires:
            vote = fcts.get_vote_commentaire_utilisateur(session["user_id"], c.id_commentaire)
            votes_utilisateur[c.id_commentaire] = vote

    photo_url = fcts.normalize_photo(getattr(oeuvre, "photo", None))

    return render_template(
        "oeuvre_detail.html",
        oeuvre=oeuvre,
        photo_url=photo_url,
        genres=genres,
        realisateurs=realisateurs,
        acteurs=acteurs,
        liens=liens,
        commentaires=commentaires,
        est_favori=oeuvre_est_favori,
        note_moyenne=moyenne,
        nb_votes=nb_votes,
        note_utilisateur=note_utilisateur,
        votes_utilisateur=votes_utilisateur,
        com_page=c_page,
        com_pages=c_pages
    )


# ═══════════════════════════════════════════════════════════════════════════
#                          GESTION DES FAVORIS
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/favori/<int:id_oeuvre>", methods=["POST"])
def ajouter_favori(id_oeuvre):
    """
    Ajoute une oeuvre aux favoris de l'utilisateur connecté
    Redirige vers la connexion si pas connecté
    """
    if "user_id" not in session:
        return redirect(url_for("connexion"))
    
    fcts.ajouter_favori(session["user_id"], id_oeuvre)
    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))

@app.route("/profil", methods=["GET", "POST"])
def profil():
    """Page profil + édition basique pseudo/email"""
    if "user_id" not in session:
        return redirect(url_for("connexion"))

    user = fcts.get_utilisateur_par_id(session["user_id"])
    favoris = fcts.get_favoris_utilisateur(session["user_id"])
    photos = fcts.get_photos_oeuvres(favoris)
    favoris_fmt = []
    for f in favoris:
        photo = photos.get(f.id_oeuvre) if photos else None
        if photo and not str(photo).startswith(("http://", "https://", "/")):
            photo = url_for("static", filename=photo)
        favoris_fmt.append({
            "id_oeuvre": f.id_oeuvre,
            "titre": f.titre,
            "type_oeuvre": f.type_oeuvre,
            "date_creation": f.date_creation,
            "date_ajout": f.date_ajout,
            "photo": photo
        })

    if request.method == "POST":
        nouveau_pseudo = request.form.get("pseudo", "").strip() or None
        nouvel_email = request.form.get("email", "").strip() or None
        avatar_emoji = request.form.get("avatar", "").strip() or None
        if nouveau_pseudo or nouvel_email:
            fcts.editer_profil(session["user_id"], pseudo=nouveau_pseudo, email=nouvel_email)
            if nouveau_pseudo:
                session["pseudo"] = nouveau_pseudo
            if nouvel_email:
                session["email"] = nouvel_email
            flash("Profil mis à jour", "success")
        if avatar_emoji:
            session["avatar_emoji"] = avatar_emoji
            flash("Avatar mis à jour", "success")
        if nouveau_pseudo or nouvel_email or avatar_emoji:
            return redirect(url_for("profil"))

    stats = {
        "favoris": len(favoris),
        "commentaires": getattr(fcts, "compter_commentaires_utilisateur", lambda *_: 0)(session["user_id"]) if hasattr(fcts, "compter_commentaires_utilisateur") else 0
    }

    return render_template("profil.html", user=user, favoris=favoris_fmt, stats=stats)


@app.route("/favoris")
def favoris():
    """Page liste des favoris de l'utilisateur"""
    if "user_id" not in session:
        return redirect(url_for("connexion"))

    tri = request.args.get("tri", "recent")
    statut = request.args.get("statut", "tout")
    favoris_raw = fcts.get_favoris_utilisateur(session["user_id"])
    photos = fcts.get_photos_oeuvres(favoris_raw)

    favoris = []
    for f in favoris_raw:
        photo = photos.get(f.id_oeuvre) if photos else None
        if photo and not str(photo).startswith(("http://", "https://", "/")):
            photo = url_for("static", filename=photo)
        favoris.append({
            "id_oeuvre": f.id_oeuvre,
            "titre": f.titre,
            "type_oeuvre": f.type_oeuvre,
            "date_creation": f.date_creation,
            "date_ajout": f.date_ajout,
            "photo": photo
        })

    if tri == "ancien":
        favoris = list(reversed(favoris))

    return render_template(
        "favoris.html",
        favoris=favoris,
        tri=tri,
        statut=statut
    )

# ═══════════════════════════════════════════════════════════════════════════
#                        GESTION DES COMMENTAIRES
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/commentaire/<int:id_oeuvre>", methods=["POST"])
def ajouter_commentaire(id_oeuvre):
    """
    Ajoute un commentaire sur une oeuvre
    Valide la longueur (5-5000 caractères) et affiche un message flash
    """
    if "user_id" not in session:
        return redirect(url_for("connexion"))

    contenu = request.form.get("contenu")
    fcts.creer_commentaire(contenu, session["user_id"], id_oeuvre)

    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))


# ═══════════════════════════════════════════════════════════════════════════
#                          GESTION DES NOTES
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/noter/<int:id_oeuvre>", methods=["POST"])
def noter_oeuvre(id_oeuvre):
    """
    Ajoute ou met à jour la note d'un utilisateur pour une oeuvre
    Note entre 1 et 5 étoiles
    """
    if "user_id" not in session:
        return redirect(url_for("connexion"))
    
    note = int(request.form.get("note"))
    fcts.ajouter_note(session["user_id"], id_oeuvre, note)

    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))


@app.route("/voter_commentaire/<int:id_commentaire>", methods=["POST"])
def voter_commentaire(id_commentaire):
    """
    Vote sur l'utilité d'un commentaire
    utile=true pour utile, utile=false pour pas utile
    """
    if "user_id" not in session:
        return redirect(url_for("connexion"))
    
    utile = request.form.get("utile") == "true"
    id_oeuvre = request.form.get("id_oeuvre")
    
    fcts.noter_commentaire(session["user_id"], id_commentaire, utile)
    return redirect(url_for("oeuvre_detail", id_oeuvre=id_oeuvre))


# ═══════════════════════════════════════════════════════════════════════════
#                      AUTHENTIFICATION: INSCRIPTION
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/inscription", methods=["GET", "POST"])
def inscription():
    """
    Création d'un nouveau compte utilisateur
    Vérifie que l'email n'existe pas déjà
    """
    if request.method == "POST":
        pseudo = request.form.get("pseudo")
        email = request.form.get("email")
        mdp = request.form.get("mdp")

        if fcts.get_utilisateur_par_email(email):
            flash("Email déjà utilisé.", "error")
            return redirect(url_for("inscription"))

        fcts.creer_utilisateur(pseudo, email, mdp)
        flash("Compte créé avec succès!", "success")
        return redirect(url_for("connexion"))

    return render_template("inscription.html")


# ═══════════════════════════════════════════════════════════════════════════
#                       AUTHENTIFICATION: CONNEXION
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/connexion", methods=["GET", "POST"])
def connexion():
    """
    Connexion utilisateur: vérifie email + mot de passe
    Bloque les comptes bannis et crée une session
    """
    if request.method == "POST":
        email = request.form.get("email")
        mdp = request.form.get("mdp")

        user = fcts.verifier_utilisateur(email, mdp)

        if not user:
            flash("Identifiants incorrects.", "error")
            return redirect(url_for("connexion"))

        if fcts.est_banni(user.id_utilisateur):
            flash("Le compte est banni!!;))))", "error")
            return redirect(url_for("connexion"))

        session["user_id"] = user.id_utilisateur
        session["pseudo"] = user.pseudo
        session["role"] = getattr(user, "role_utilisateur", None)
        session["email"] = getattr(user, "email", None)

        return redirect(url_for("accueil"))

    return render_template("connexion.html")


# ═══════════════════════════════════════════════════════════════════════════
#                      AUTHENTIFICATION: DÉCONNEXION
# ═══════════════════════════════════════════════════════════════════════════
@app.route("/deconnexion")
def deconnexion():
    """Déconnexion: efface toute la session et redirige vers l'accueil"""
    session.clear()
    return redirect(url_for("accueil"))


# ═══════════════════════════════════════════════════════════════════════════
#                      GESTION DES ERREURS & REDIRECTIONS
# ═══════════════════════════════════════════════════════════════════════════
@app.errorhandler(404)
def page_404(e):
    """Gestion des pages introuvables(404)"""
    return render_template("404.html"), 404


@app.route("/accueil")
def accueil_redirect():
    """Redirection /accueil → /"""
    return redirect(url_for("accueil"))


@app.route("/oeuvre/")
def oeuvre_redirect():
    """Redirection /oeuvre/ → /oeuvres"""
    return redirect(url_for("oeuvres"))



# ═══════════════════════════════════════════════════════════════════════════
#                          LANCEMENT DU SERVEUR
# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__": 
	app.run(debug=False, use_reloader=False)
