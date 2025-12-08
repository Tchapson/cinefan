DROP TABLE IF EXISTS realise CASCADE;
DROP TABLE IF EXISTS appartient CASCADE;
DROP TABLE IF EXISTS joue CASCADE;
DROP TABLE IF EXISTS lien CASCADE;
DROP TABLE IF EXISTS favoris CASCADE;
DROP TABLE IF EXISTS episode CASCADE;
DROP TABLE IF EXISTS photo CASCADE;
DROP TABLE IF EXISTS categorie CASCADE;
DROP TABLE IF EXISTS personnage CASCADE;
DROP TABLE IF EXISTS commentaire CASCADE;
DROP TABLE IF EXISTS artiste CASCADE;
DROP TABLE IF EXISTS oeuvre CASCADE;
DROP TABLE IF EXISTS utilisateur CASCADE;

DROP TABLE IF EXISTS realise;
DROP TABLE IF EXISTS appartient;
DROP TABLE IF EXISTS joue;
DROP TABLE IF EXISTS lien;
DROP TABLE IF EXISTS favoris;
DROP TABLE IF EXISTS episode;
DROP TABLE IF EXISTS photo;
DROP TABLE IF EXISTS categorie;
DROP TABLE IF EXISTS personnage;
DROP TABLE IF EXISTS commentaire;
DROP TABLE IF EXISTS artiste;
DROP TABLE IF EXISTS oeuvre;
DROP TABLE IF EXISTS utilisateur;

CREATE TABLE utilisateur(
    id_utilisateur serial PRIMARY KEY,
    pseudo varchar(50) NOT NULL,
    email varchar(50) UNIQUE NOT NULL,
    mdp char(8) NOT NULL,
    role_utilisateur varchar(10) DEFAULT 'user'
);

CREATE TABLE oeuvre(
    id_oeuvre serial PRIMARY KEY,
    titre text NOT NULL,
    numero_volet_saison int,
    type_oeuvre varchar(50) NOT NULL,
    date_creation date NOT NULL,
    description_oeuvre text
);

CREATE TABLE artiste(
    id_artiste serial PRIMARY KEY,
    nom varchar(50) NOT NULL,
    prenom varchar(50) NOT NULL,
    date_naissance date NOT NULL,
    biographie text,
    UNIQUE(nom, prenom)
);

CREATE TABLE commentaire(
    id_commentaire serial PRIMARY KEY,
    contenu text NOT NULL,
    date_commentaire date NOT NULL,
    id_utilisateur int REFERENCES utilisateur(id_utilisateur),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre)
);

CREATE TABLE personnage(
    id_personnage serial PRIMARY KEY,
    libelle varchar(50) NOT NULL
);

CREATE TABLE categorie(
    nom_cat varchar(50) PRIMARY KEY
);

CREATE TABLE photo(
    id_photo serial PRIMARY KEY,
    chemin varchar(200) NOT NULL,
    description_ text,
    id_utilisateur int REFERENCES utilisateur(id_utilisateur),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre)
);

CREATE TABLE episode(
    id_episode serial PRIMARY KEY,
    titre text NOT NULL,
    num_ep varchar(100),
    synopsie text,
    id_oeuvre int REFERENCES oeuvre(id_oeuvre)
);

CREATE TABLE favoris(
    id_utilisateur int REFERENCES utilisateur(id_utilisateur),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre),
    date_ajout date NOT NULL,
    PRIMARY KEY(id_utilisateur, id_oeuvre)
);

CREATE TABLE lien(
    id_oeuvre1 int REFERENCES oeuvre(id_oeuvre),
    id_oeuvre2 int REFERENCES oeuvre(id_oeuvre),
    type_lien varchar(20) NOT NULL,
    PRIMARY KEY (id_oeuvre1, id_oeuvre2)
);

CREATE TABLE joue(
    id_artiste int REFERENCES artiste(id_artiste),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre),
    id_personnage int REFERENCES personnage(id_personnage),
    PRIMARY KEY (id_artiste, id_oeuvre, id_personnage)
);

CREATE TABLE appartient(
    id_oeuvre int REFERENCES oeuvre(id_oeuvre),
    nom_cat varchar(50) REFERENCES categorie(nom_cat),
    PRIMARY KEY(id_oeuvre, nom_cat)
);

CREATE TABLE realise(
    id_artiste int REFERENCES artiste(id_artiste),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre),
    PRIMARY KEY (id_artiste, id_oeuvre)
);

------------------- VUES ------------------

CREATE VIEW NbFilmsGenreParActeur AS (
    SELECT artiste.id_artiste,
           artiste.nom,
           artiste.prenom,
           appartient.nom_cat,
           COUNT(*) AS nb_films
    FROM joue
    JOIN oeuvre ON oeuvre.id_oeuvre = joue.id_oeuvre
    JOIN appartient ON appartient.id_oeuvre = oeuvre.id_oeuvre
    JOIN artiste ON joue.id_artiste = artiste.id_artiste
    GROUP BY artiste.id_artiste, artiste.nom, artiste.prenom, appartient.nom_cat
    ORDER BY nb_films DESC
);

CREATE VIEW NbCrtiquesUtilisateur AS (
    SELECT utilisateur.id_utilisateur,
           utilisateur.pseudo,
           COUNT(id_commentaire) AS nb_commentaires
    FROM utilisateur
    LEFT JOIN commentaire ON utilisateur.id_utilisateur = commentaire.id_utilisateur
    GROUP BY utilisateur.id_utilisateur, pseudo
);

CREATE VIEW NbCrtiquesMoyParGenre AS (
    SELECT c.nom_cat AS genre,
           COUNT(co.id_commentaire) * 1.0 /
                (SELECT COUNT(*) FROM utilisateur) AS moyenne_par_utilisateur
    FROM commentaire co
    JOIN oeuvre o ON co.id_oeuvre = o.id_oeuvre
    JOIN appartient ap ON o.id_oeuvre = ap.id_oeuvre
    JOIN categorie c ON ap.nom_cat = c.nom_cat
    GROUP BY c.nom_cat
);

----------------- REMPLISSAGE TABLES --------------------

INSERT INTO utilisateur (pseudo, email, mdp, role_utilisateur) VALUES
('LukeFan', 'luke@mail.com', 'skyw000', 'user'),
('WinterIsComing', 'snow@mail.com', 'sword987', 'user'),
('AdminBoss', 'admin@mail.com', 'admin007', 'admin'),
('MarvelAddict', 'marvel@mail.com', 'avngrs42', 'user'),
('CineCritique', 'critique@mail.com', 'review99', 'user');

INSERT INTO artiste (nom, prenom, date_naissance, biographie) VALUES
('DiCaprio', 'Leonardo', '1974-11-11', 'Acteur américain, Inception, Titanic'),
('Portman', 'Natalie', '1981-06-09', 'Actrice, Star Wars, Black Swan'),
('Ford', 'Harrison', '1942-07-13', 'Acteur, Han Solo, Indiana Jones'),
('Hamill', 'Mark', '1951-09-25', 'Acteur, Luke Skywalker'),
('Harington', 'Kit', '1986-12-26', 'Acteur, Jon Snow dans Game of Thrones');

INSERT INTO oeuvre (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre) VALUES
('Inception', NULL, 'film', '2010-07-16', 'Film de science-fiction de Christopher Nolan'),
('Star Wars', 4, 'film', '1977-05-25', 'Episode IV : Un Nouvel Espoir'),
('Star Wars', 5, 'film', '1980-05-21', 'Episode V : L Empite contre-attaque'),
('Star Wars', 6, 'film', '1983-05-25', 'Episode VI : Le Retour du Jedi'),
('Game of Thrones', 1, 'série', '2011-04-17', 'Saison 1 de la série HBO'),
('Game of Thrones', 2, 'série', '2012-04-01', 'Saison 2 de la série HBO');

INSERT INTO categorie VALUES
('Science-Fiction'),
('Fantastique'),
('Drame'),
('Aventure');

INSERT INTO appartient VALUES
(1, 'Science-Fiction'),
(1, 'Drame'),
(2, 'Science-Fiction'),
(2, 'Aventure'),
(3, 'Aventure'),
(4, 'Aventure'),
(5, 'Fantastique'),
(5, 'Drame'),
(6, 'Fantastique');

INSERT INTO personnage (libelle) VALUES
('Dom Cobb'),
('Luke Skywalker'),
('Han Solo'),
('Princess Leia'),
('Jon Snow'),
('Jimmy Mcgil');

INSERT INTO joue VALUES
(1, 1, 1),  -- DiCaprio joue Dom Cobb (Inception)
(4, 2, 2),  -- Mark Hamill — Luke Skywalker — Star Wars IV
(4, 3, 2),  -- Mark Hamill — Luke — Star Wars V
(4, 4, 2),  -- Mark Hamill — Luke — Star Wars VI
(3, 3, 3),  -- Harrison Ford — Han Solo — Star Wars V
(3, 4, 2),  -- Harrison Ford — Han Solo — Star Wars VI
(5, 5, 5),  -- Kit Harington — Jon Snow — GoT S1
(5, 6, 5);  -- Kit Harington — Jon Snow — GoT S2

INSERT INTO commentaire (contenu, date_commentaire, id_utilisateur, id_oeuvre) VALUES
('Chef-d’œuvre absolu', '2024-01-12', 1, 1),
('Effets spéciaux incroyables', '2024-01-13', 2, 1),
('Film culte, indétrônable', '2024-01-14', 3, 2),
('Meilleur épisode de la trilogie originale!', '2024-01-14', 1, 3),
('Une saison captivante', '2024-01-15', 2, 5),
('La bataille finale est incroyable', '2024-01-16', 4, 6),
('Très bon développement de Jon Snow', '2024-01-16', 5, 6);

INSERT INTO photo (chemin, description_, id_utilisateur, id_oeuvre) VALUES
('/images/inception.jpg', 'Affiche officielle', 1, 1),
('/images/starwars4.jpg', 'Poster original Star Wars IV', 3, 2),
('/images/got_s1.jpg', 'Affiche saison 1', 2, 5);

INSERT INTO favoris VALUES
(1, 1, '2024-01-10'), -- Inception
(1, 2, '2024-01-10'), -- Star Wars IV
(2, 5, '2024-01-11'), -- GoT S1
(4, 2, '2024-01-12'), -- Star Wars IV
(5, 1, '2024-01-13'); -- Inception
