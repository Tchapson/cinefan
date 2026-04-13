DROP TABLE IF EXISTS note_commentaire CASCADE;
DROP TABLE IF EXISTS note CASCADE;
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

DROP TABLE IF EXISTS note_commentaire;
DROP TABLE IF EXISTS note;
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
    mdp text NOT NULL,
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

CREATE TABLE note(
    id_utilisateur int REFERENCES utilisateur(id_utilisateur),
    id_oeuvre int REFERENCES oeuvre(id_oeuvre),
    note int CHECK (note BETWEEN 1 AND 5) NOT NULL,
    date_note date DEFAULT CURRENT_DATE,
    PRIMARY KEY (id_utilisateur, id_oeuvre)
);

CREATE TABLE note_commentaire(
    id_utilisateur int REFERENCES utilisateur(id_utilisateur),
    id_commentaire int REFERENCES commentaire(id_commentaire),
    utile boolean NOT NULL,
    PRIMARY KEY (id_utilisateur, id_commentaire)
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

CREATE VIEW moyenne_notes_oeuvre AS (
    SELECT id_oeuvre,
           ROUND(AVG(note)::numeric, 1) AS moyenne,
           COUNT(*) AS nb_votes
    FROM note
    GROUP BY id_oeuvre
);

CREATE VIEW top_oeuvres AS (
    SELECT o.id_oeuvre,
           o.titre,
           o.type_oeuvre,
           m.moyenne,
           m.nb_votes
    FROM oeuvre o
    JOIN moyenne_notes_oeuvre m ON o.id_oeuvre = m.id_oeuvre
    WHERE m.nb_votes >= 3
    ORDER BY m.moyenne DESC, m.nb_votes DESC
    LIMIT 20
);

CREATE VIEW moyenne_notes_par_genre AS (
    SELECT c.nom_cat,
           ROUND(AVG(n.note)::numeric, 1) AS moyenne,
           COUNT(*) AS nb_votes
    FROM note n
    JOIN appartient a ON n.id_oeuvre = a.id_oeuvre
    JOIN categorie c ON a.nom_cat = c.nom_cat
    GROUP BY c.nom_cat
    ORDER BY moyenne DESC
);

CREATE VIEW commentaires_avec_utilite AS (
    SELECT c.id_commentaire,
           c.contenu,
           c.date_commentaire,
           c.id_utilisateur,
           c.id_oeuvre,
           u.pseudo,
           COUNT(CASE WHEN nc.utile = true THEN 1 END) AS nb_utiles,
           COUNT(CASE WHEN nc.utile = false THEN 1 END) AS nb_non_utiles,
           COUNT(nc.id_utilisateur) AS nb_votes_total
    FROM commentaire c
    JOIN utilisateur u ON c.id_utilisateur = u.id_utilisateur
    LEFT JOIN note_commentaire nc ON c.id_commentaire = nc.id_commentaire
    GROUP BY c.id_commentaire, c.contenu, c.date_commentaire, c.id_utilisateur, c.id_oeuvre, u.pseudo
);

----------------- REMPLISSAGE TABLES --------------------

-- ═══════════════════════════════════════════════════════════
--                        UTILISATEURS
-- ═══════════════════════════════════════════════════════════

INSERT INTO utilisateur (pseudo, email, mdp, role_utilisateur) VALUES
('LukeFan', 'luke@mail.com', 'skyw000', 'user'),
('WinterIsComing', 'snow@mail.com', 'sword987', 'user'),
('AdminBoss', 'admin@mail.com', 'admin007', 'admin'),
('MarvelAddict', 'marvel@mail.com', 'avngrs42', 'user'),
('CineCritique', 'critique@mail.com', 'review99', 'user'),
('MovieBuff2024', 'moviebuff@mail.com', 'cinema456', 'user'),
('FilmNoir_Lover', 'noirfan@mail.com', 'darkness12', 'user'),
('SeriesAddict', 'series@mail.com', 'binge789', 'user'),
('SciFiGeek', 'scifi@mail.com', 'space999', 'user'),
('HorrorFanatic', 'horror@mail.com', 'scary666', 'user'),
('RomComQueen', 'romcom@mail.com', 'love123', 'user'),
('ActionHero', 'action@mail.com', 'boom777', 'user'),
('ThrillerFan', 'thriller@mail.com', 'suspense55', 'user'),
('AnimeLover', 'anime@mail.com', 'manga888', 'user'),
('ClassicCinema', 'classic@mail.com', 'oldies44', 'user'),
('DocumentaryFan', 'docus@mail.com', 'facts321', 'user'),
('IndieSupporter', 'indie@mail.com', 'arthouse99', 'user'),
('ComedyKing', 'comedy@mail.com', 'lol555', 'user'),
('DramaQueen', 'drama@mail.com', 'tears222', 'user'),
('FantasyDreamer', 'fantasy@mail.com', 'magic111', 'user');

-- ═══════════════════════════════════════════════════════════
--                         ARTISTES
-- ═══════════════════════════════════════════════════════════

INSERT INTO artiste (nom, prenom, date_naissance, biographie) VALUES
('DiCaprio', 'Leonardo', '1974-11-11', 'Acteur américain, Inception, Titanic'),
('Portman', 'Natalie', '1981-06-09', 'Actrice, Star Wars, Black Swan'),
('Ford', 'Harrison', '1942-07-13', 'Acteur, Han Solo, Indiana Jones'),
('Hamill', 'Mark', '1951-09-25', 'Acteur, Luke Skywalker'),
('Harington', 'Kit', '1986-12-26', 'Acteur, Jon Snow dans Game of Thrones'),
('Nolan', 'Christopher', '1970-07-30', 'Réalisateur britannique, Inception, The Dark Knight'),
('Tarantino', 'Quentin', '1963-03-27', 'Réalisateur américain, Pulp Fiction, Django'),
('Scorsese', 'Martin', '1942-11-17', 'Réalisateur américain, Goodfellas, The Wolf of Wall Street'),
('Fincher', 'David', '1962-08-28', 'Réalisateur américain, Fight Club, Seven'),
('Villeneuve', 'Denis', '1967-10-03', 'Réalisateur canadien, Dune, Blade Runner 2049'),
('Cruise', 'Tom', '1962-07-03', 'Acteur américain, Mission Impossible, Top Gun'),
('Pitt', 'Brad', '1963-12-18', 'Acteur américain, Fight Club, Once Upon a Time'),
('Johansson', 'Scarlett', '1984-11-22', 'Actrice américaine, Avengers, Lost in Translation'),
('Downey Jr', 'Robert', '1965-04-04', 'Acteur américain, Iron Man, Sherlock Holmes'),
('Hemsworth', 'Chris', '1983-08-11', 'Acteur australien, Thor, Avengers'),
('Robbie', 'Margot', '1990-07-02', 'Actrice australienne, Barbie, Suicide Squad'),
('Gosling', 'Ryan', '1980-11-12', 'Acteur canadien, Blade Runner 2049, La La Land'),
('Stone', 'Emma', '1988-11-06', 'Actrice américaine, La La Land, Poor Things'),
('Phoenix', 'Joaquin', '1974-10-28', 'Acteur américain, Joker, Her'),
('Blanchett', 'Cate', '1969-05-14', 'Actrice australienne, Lord of the Rings, Blue Jasmine'),
('Washington', 'Denzel', '1954-12-28', 'Acteur américain, Training Day, Malcolm X'),
('Freeman', 'Morgan', '1937-06-01', 'Acteur américain, Shawshank Redemption, Se7en'),
('Hanks', 'Tom', '1956-07-09', 'Acteur américain, Forrest Gump, Cast Away'),
('Streep', 'Meryl', '1949-06-22', 'Actrice américaine, The Devil Wears Prada, Sophie Choice'),
('Dench', 'Judi', '1934-12-09', 'Actrice britannique, James Bond, Shakespeare in Love'),
('Hopkins', 'Anthony', '1937-12-31', 'Acteur britannique, Silence of the Lambs, The Father'),
('Bale', 'Christian', '1974-01-30', 'Acteur britannique, Batman, The Machinist'),
('Hardy', 'Tom', '1977-09-15', 'Acteur britannique, Mad Max, Inception'),
('Hathaway', 'Anne', '1982-11-12', 'Actrice américaine, Les Misérables, Interstellar'),
('Chalamet', 'Timothée', '1995-12-27', 'Acteur américain, Dune, Call Me By Your Name'),
('Zendaya', 'Maree', '1996-09-01', 'Actrice américaine, Euphoria, Dune'),
('Pugh', 'Florence', '1996-01-03', 'Actrice britannique, Little Women, Black Widow'),
('Driver', 'Adam', '1983-11-19', 'Acteur américain, Star Wars, Marriage Story'),
('Isaac', 'Oscar', '1979-03-09', 'Acteur américain, Dune, Ex Machina'),
('Murphy', 'Cillian', '1976-05-25', 'Acteur irlandais, Oppenheimer, Peaky Blinders'),
('Jackson', 'Samuel L.', '1948-12-21', 'Acteur américain, Pulp Fiction, Avengers'),
('Keaton', 'Michael', '1951-09-05', 'Acteur américain, Batman, Birdman'),
('Neeson', 'Liam', '1952-06-07', 'Acteur irlandais, Taken, Schindler List'),
('Willis', 'Bruce', '1955-03-19', 'Acteur américain, Die Hard, Pulp Fiction'),
('Reeves', 'Keanu', '1964-09-02', 'Acteur canadien, Matrix, John Wick');

-- ═══════════════════════════════════════════════════════════
--                         OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO oeuvre (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre) VALUES
('Inception', NULL, 'film', '2010-07-16', 'Film de science-fiction de Christopher Nolan'),
('Star Wars', 4, 'film', '1977-05-25', 'Episode IV : Un Nouvel Espoir'),
('Star Wars', 5, 'film', '1980-05-21', 'Episode V : L Empire contre-attaque'),
('Star Wars', 6, 'film', '1983-05-25', 'Episode VI : Le Retour du Jedi'),
('Game of Thrones', 1, 'série', '2011-04-17', 'Saison 1 de la série HBO'),
('Game of Thrones', 2, 'série', '2012-04-01', 'Saison 2 de la série HBO'),
('The Dark Knight', NULL, 'film', '2008-07-18', 'Batman affronte le Joker dans Gotham City'),
('Pulp Fiction', NULL, 'film', '1994-10-14', 'Film culte de Quentin Tarantino'),
('Fight Club', NULL, 'film', '1999-10-15', 'Un homme découvre un club de combat clandestin'),
('The Matrix', NULL, 'film', '1999-03-31', 'Neo découvre la vérité sur la réalité'),
('Interstellar', NULL, 'film', '2014-11-07', 'Voyage spatial pour sauver l humanité'),
('The Shawshank Redemption', NULL, 'film', '1994-09-23', 'Histoire d amitié en prison'),
('Forrest Gump', NULL, 'film', '1994-07-06', 'Parcours extraordinaire d un homme simple'),
('The Godfather', NULL, 'film', '1972-03-24', 'Saga mafieuse de la famille Corleone'),
('Goodfellas', NULL, 'film', '1990-09-19', 'Ascension et chute d un gangster'),
('Se7en', NULL, 'film', '1995-09-22', 'Enquête sur un tueur en série inspiré des 7 péchés'),
('The Silence of the Lambs', NULL, 'film', '1991-02-14', 'Agent FBI consulte Hannibal Lecter'),
('Blade Runner 2049', NULL, 'film', '2017-10-06', 'Suite du classique de science-fiction'),
('Dune', 1, 'film', '2021-10-22', 'Première partie de l adaptation du roman'),
('Dune', 2, 'film', '2024-03-01', 'Suite de l épopée sur Arrakis'),
('Avengers: Endgame', NULL, 'film', '2019-04-26', 'Bataille finale contre Thanos'),
('Avengers: Infinity War', NULL, 'film', '2018-04-27', 'Les Avengers face à Thanos'),
('Iron Man', NULL, 'film', '2008-05-02', 'Tony Stark devient Iron Man'),
('Thor', NULL, 'film', '2011-05-06', 'Le dieu du tonnerre banni sur Terre'),
('Barbie', NULL, 'film', '2023-07-21', 'Barbie découvre le monde réel'),
('Oppenheimer', NULL, 'film', '2023-07-21', 'Biographie du père de la bombe atomique'),
('The Wolf of Wall Street', NULL, 'film', '2013-12-25', 'Ascension d un courtier corrompu'),
('Titanic', NULL, 'film', '1997-12-19', 'Romance tragique sur le Titanic'),
('The Lord of the Rings', 1, 'film', '2001-12-19', 'La Communauté de l Anneau'),
('The Lord of the Rings', 2, 'film', '2002-12-18', 'Les Deux Tours'),
('The Lord of the Rings', 3, 'film', '2003-12-17', 'Le Retour du Roi'),
('Breaking Bad', 1, 'série', '2008-01-20', 'Prof de chimie devient fabricant de meth'),
('Breaking Bad', 2, 'série', '2009-03-08', 'Walter White s enfonce dans le crime'),
('Breaking Bad', 3, 'série', '2010-03-21', 'Tensions avec Gus Fring'),
('Breaking Bad', 4, 'série', '2011-07-17', 'Confrontation avec Gus'),
('Breaking Bad', 5, 'série', '2012-07-15', 'Saison finale épique'),
('Stranger Things', 1, 'série', '2016-07-15', 'Disparition mystérieuse dans une petite ville'),
('Stranger Things', 2, 'série', '2017-10-27', 'Le retour de l Upside Down'),
('Stranger Things', 3, 'série', '2019-07-04', 'Été 1985 à Hawkins'),
('Stranger Things', 4, 'série', '2022-05-27', 'Face à Vecna'),
('The Mandalorian', 1, 'série', '2019-11-12', 'Chasseur de primes et Baby Yoda'),
('The Mandalorian', 2, 'série', '2020-10-30', 'Aventures continues dans Star Wars'),
('The Crown', 1, 'série', '2016-11-04', 'Règne d Elizabeth II'),
('The Crown', 2, 'série', '2017-12-08', 'Années 1960'),
('Peaky Blinders', 1, 'série', '2013-09-12', 'Gang de Birmingham après WWI'),
('Peaky Blinders', 2, 'série', '2014-10-02', 'Expansion du gang Shelby'),
('The Witcher', 1, 'série', '2019-12-20', 'Geralt de Riv chasseur de monstres'),
('The Witcher', 2, 'série', '2021-12-17', 'Quête de Ciri'),
('House of the Dragon', 1, 'série', '2022-08-21', 'Préquelle de Game of Thrones'),
('House of the Dragon', 2, 'série', '2024-06-16', 'Guerre civile Targaryen');

-- ═══════════════════════════════════════════════════════════
--                        CATÉGORIES
-- ═══════════════════════════════════════════════════════════

INSERT INTO categorie VALUES
('Science-Fiction'),
('Fantastique'),
('Drame'),
('Aventure'),
('Action'),
('Thriller'),
('Crime'),
('Comédie'),
('Romance'),
('Horreur'),
('Animation'),
('Documentaire'),
('Guerre'),
('Historique'),
('Biographie'),
('Musical'),
('Western'),
('Mystère');

-- ═══════════════════════════════════════════════════════════
--                    GENRES DES OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO appartient VALUES
-- Inception
(1, 'Science-Fiction'),
(1, 'Thriller'),
(1, 'Action'),
-- Star Wars
(2, 'Science-Fiction'),
(2, 'Aventure'),
(3, 'Science-Fiction'),
(3, 'Aventure'),
(4, 'Science-Fiction'),
(4, 'Aventure'),
-- Game of Thrones
(5, 'Fantastique'),
(5, 'Drame'),
(5, 'Aventure'),
(6, 'Fantastique'),
(6, 'Drame'),
-- The Dark Knight
(7, 'Action'),
(7, 'Crime'),
(7, 'Thriller'),
-- Pulp Fiction
(8, 'Crime'),
(8, 'Thriller'),
(8, 'Drame'),
-- Fight Club
(9, 'Drame'),
(9, 'Thriller'),
-- The Matrix
(10, 'Science-Fiction'),
(10, 'Action'),
-- Interstellar
(11, 'Science-Fiction'),
(11, 'Drame'),
(11, 'Aventure'),
-- Shawshank
(12, 'Drame'),
-- Forrest Gump
(13, 'Drame'),
(13, 'Romance'),
-- The Godfather
(14, 'Crime'),
(14, 'Drame'),
-- Goodfellas
(15, 'Crime'),
(15, 'Drame'),
(15, 'Biographie'),
-- Se7en
(16, 'Crime'),
(16, 'Thriller'),
(16, 'Mystère'),
-- Silence of the Lambs
(17, 'Crime'),
(17, 'Thriller'),
(17, 'Horreur'),
-- Blade Runner 2049
(18, 'Science-Fiction'),
(18, 'Thriller'),
-- Dune
(19, 'Science-Fiction'),
(19, 'Aventure'),
(20, 'Science-Fiction'),
(20, 'Aventure'),
-- Avengers
(21, 'Action'),
(21, 'Science-Fiction'),
(21, 'Aventure'),
(22, 'Action'),
(22, 'Science-Fiction'),
(22, 'Aventure'),
(23, 'Action'),
(23, 'Science-Fiction'),
(24, 'Action'),
(24, 'Fantastique'),
(24, 'Aventure'),
-- Barbie
(25, 'Comédie'),
(25, 'Aventure'),
-- Oppenheimer
(26, 'Biographie'),
(26, 'Drame'),
(26, 'Historique'),
-- Wolf of Wall Street
(27, 'Biographie'),
(27, 'Crime'),
(27, 'Comédie'),
-- Titanic
(28, 'Romance'),
(28, 'Drame'),
-- LOTR
(29, 'Fantastique'),
(29, 'Aventure'),
(30, 'Fantastique'),
(30, 'Aventure'),
(31, 'Fantastique'),
(31, 'Aventure'),
-- Breaking Bad
(32, 'Crime'),
(32, 'Drame'),
(32, 'Thriller'),
(33, 'Crime'),
(33, 'Drame'),
(34, 'Crime'),
(34, 'Drame'),
(35, 'Crime'),
(35, 'Drame'),
(36, 'Crime'),
(36, 'Drame'),
-- Stranger Things
(37, 'Science-Fiction'),
(37, 'Horreur'),
(37, 'Mystère'),
(38, 'Science-Fiction'),
(38, 'Horreur'),
(39, 'Science-Fiction'),
(39, 'Horreur'),
(40, 'Science-Fiction'),
(40, 'Horreur'),
-- Mandalorian
(41, 'Science-Fiction'),
(41, 'Aventure'),
(42, 'Science-Fiction'),
(42, 'Aventure'),
-- The Crown
(43, 'Drame'),
(43, 'Historique'),
(44, 'Drame'),
(44, 'Historique'),
-- Peaky Blinders
(45, 'Crime'),
(45, 'Drame'),
(46, 'Crime'),
(46, 'Drame'),
-- The Witcher
(47, 'Fantastique'),
(47, 'Aventure'),
(48, 'Fantastique'),
(48, 'Aventure'),
-- House of the Dragon
(49, 'Fantastique'),
(49, 'Drame'),
(49, 'Aventure'),
(50, 'Fantastique'),
(50, 'Drame');

-- ═══════════════════════════════════════════════════════════
--                       PERSONNAGES
-- ═══════════════════════════════════════════════════════════

INSERT INTO personnage (libelle) VALUES
('Dom Cobb'),
('Luke Skywalker'),
('Han Solo'),
('Princess Leia'),
('Jon Snow'),
('Daenerys Targaryen'),
('Tyrion Lannister'),
('Bruce Wayne / Batman'),
('Joker'),
('Vincent Vega'),
('Jules Winnfield'),
('Tyler Durden'),
('Neo'),
('Trinity'),
('Morpheus'),
('Cooper'),
('Andy Dufresne'),
('Red'),
('Forrest Gump'),
('Vito Corleone'),
('Michael Corleone'),
('Henry Hill'),
('Detective Mills'),
('Detective Somerset'),
('Clarice Starling'),
('Hannibal Lecter'),
('Officer K'),
('Paul Atreides'),
('Lady Jessica'),
('Chani'),
('Tony Stark / Iron Man'),
('Thor'),
('Natasha Romanoff / Black Widow'),
('Steve Rogers / Captain America'),
('Barbie'),
('Ken'),
('J. Robert Oppenheimer'),
('Jordan Belfort'),
('Jack Dawson'),
('Rose DeWitt Bukater'),
('Frodo Baggins'),
('Gandalf'),
('Aragorn'),
('Walter White'),
('Jesse Pinkman'),
('Eleven'),
('Mike Wheeler'),
('Dustin Henderson'),
('Din Djarin / The Mandalorian'),
('Grogu'),
('Queen Elizabeth II'),
('Thomas Shelby'),
('Arthur Shelby'),
('Geralt of Rivia'),
('Yennefer'),
('Ciri'),
('Rhaenyra Targaryen'),
('Daemon Targaryen');

-- ═══════════════════════════════════════════════════════════
--            ACTEURS JOUENT DES PERSONNAGES
-- ═══════════════════════════════════════════════════════════

INSERT INTO joue VALUES
-- Inception (1)
(1, 1, 1),   -- DiCaprio joue Dom Cobb
(28, 1, 16), -- Tom Hardy joue un personnage dans Inception
-- Star Wars
(4, 2, 2),   -- Mark Hamill — Luke Skywalker — Star Wars IV
(3, 2, 3),   -- Harrison Ford — Han Solo — Star Wars IV
(2, 2, 4),   -- Natalie Portman — Princess Leia
(4, 3, 2),   -- Mark Hamill — Luke — Star Wars V
(3, 3, 3),   -- Harrison Ford — Han Solo — Star Wars V
(4, 4, 2),   -- Mark Hamill — Luke — Star Wars VI
(3, 4, 3),   -- Harrison Ford — Han Solo — Star Wars VI
-- Game of Thrones
(5, 5, 5),   -- Kit Harington — Jon Snow — GoT S1
(5, 6, 5),   -- Kit Harington — Jon Snow — GoT S2
-- The Dark Knight (7)
(27, 7, 8),  -- Christian Bale — Batman
(19, 7, 9),  -- Joaquin Phoenix comme Joker (hypothétique)
-- Pulp Fiction (8)
(11, 8, 10), -- Tom Cruise — Vincent Vega (hypothétique)
(36, 8, 11), -- Samuel L. Jackson — Jules Winnfield
(39, 8, 11), -- Bruce Willis dans Pulp Fiction
-- Fight Club (9)
(12, 9, 12), -- Brad Pitt — Tyler Durden
-- The Matrix (10)
(40, 10, 13), -- Keanu Reeves — Neo
-- Interstellar (11)
(29, 11, 16), -- Anne Hathaway — Cooper
-- Shawshank (12)
(22, 12, 17), -- Morgan Freeman — Red
-- Forrest Gump (13)
(23, 13, 19), -- Tom Hanks — Forrest Gump
-- The Godfather (14)
(26, 14, 20), -- Anthony Hopkins — Vito (hypothétique)
-- Goodfellas (15)
(21, 15, 22), -- Denzel Washington — Henry Hill (hypothétique)
-- Se7en (16)
(22, 16, 24), -- Morgan Freeman — Somerset
(12, 16, 23), -- Brad Pitt — Mills
-- Silence of the Lambs (17)
(26, 17, 26), -- Anthony Hopkins — Hannibal Lecter
-- Blade Runner 2049 (18)
(17, 18, 27), -- Ryan Gosling — Officer K
-- Dune (19, 20)
(30, 19, 28), -- Timothée Chalamet — Paul Atreides
(31, 19, 30), -- Zendaya — Chani
(30, 20, 28), -- Timothée Chalamet — Paul Atreides
(31, 20, 30), -- Zendaya — Chani
(34, 19, 29), -- Oscar Isaac — Duke Leto
-- Avengers (21, 22, 23)
(14, 21, 31), -- Robert Downey Jr — Iron Man
(15, 21, 32), -- Chris Hemsworth — Thor
(13, 21, 33), -- Scarlett Johansson — Black Widow
(14, 22, 31), -- Robert Downey Jr — Iron Man
(15, 22, 32), -- Chris Hemsworth — Thor
(14, 23, 31), -- Robert Downey Jr — Iron Man
-- Thor (24)
(15, 24, 32), -- Chris Hemsworth — Thor
-- Barbie (25)
(16, 25, 35), -- Margot Robbie — Barbie
(17, 25, 36), -- Ryan Gosling — Ken
-- Oppenheimer (26)
(35, 26, 37), -- Cillian Murphy — Oppenheimer
-- Wolf of Wall Street (27)
(1, 27, 38),  -- DiCaprio — Jordan Belfort
-- Titanic (28)
(1, 28, 39),  -- DiCaprio — Jack
-- Breaking Bad (32-36)
(35, 32, 44), -- Cillian Murphy — Walter White (hypothétique)
(35, 33, 44),
(35, 34, 44),
(35, 35, 44),
(35, 36, 44),
-- Peaky Blinders (45-46)
(35, 45, 52), -- Cillian Murphy — Thomas Shelby
(35, 46, 52);

-- ═══════════════════════════════════════════════════════════
--                       RÉALISATEURS
-- ═══════════════════════════════════════════════════════════

INSERT INTO realise VALUES
(6, 1),   -- Nolan — Inception
(6, 7),   -- Nolan — Dark Knight
(6, 11),  -- Nolan — Interstellar
(7, 8),   -- Tarantino — Pulp Fiction
(8, 15),  -- Scorsese — Goodfellas
(8, 27),  -- Scorsese — Wolf of Wall Street
(9, 9),   -- Fincher — Fight Club
(9, 16),  -- Fincher — Se7en
(10, 18), -- Villeneuve — Blade Runner 2049
(10, 19), -- Villeneuve — Dune 1
(10, 20); -- Villeneuve — Dune 2

-- ═══════════════════════════════════════════════════════════
--                       COMMENTAIRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO commentaire (contenu, date_commentaire, id_utilisateur, id_oeuvre) VALUES
-- Inception
('Chef-d''oeuvre absolu', '2024-01-12', 1, 1),
('Effets spéciaux incroyables', '2024-01-13', 2, 1),
('Christopher Nolan au sommet de son art', '2024-01-14', 3, 1),
('Scénario brillant et complexe', '2024-01-15', 4, 1),
('Meilleur film de science-fiction de la décennie', '2024-01-16', 5, 1),
-- Star Wars
('Film culte, indétrônable', '2024-01-14', 3, 2),
('La Force est puissante avec celui-ci', '2024-01-17', 6, 2),
('Une saga intemporelle', '2024-01-18', 7, 2),
('Meilleur épisode de la trilogie originale!', '2024-01-14', 1, 3),
('L''Empire contre-attaque reste le meilleur', '2024-01-19', 8, 3),
('Vader est incroyable', '2024-01-20', 9, 3),
('Belle conclusion de la trilogie', '2024-01-21', 10, 4),
-- Game of Thrones
('Une saison captivante', '2024-01-15', 2, 5),
('Les Stark sont mes préférés', '2024-01-22', 11, 5),
('L''intrigue politique est fascinante', '2024-01-23', 12, 5),
('La bataille finale est incroyable', '2024-01-16', 4, 6),
('Très bon développement de Jon Snow', '2024-01-16', 5, 6),
('Tyrion vole la vedette', '2024-01-24', 13, 6),
-- The Dark Knight
('Le meilleur film de super-héros jamais réalisé', '2024-01-25', 14, 7),
('Heath Ledger est légendaire en Joker', '2024-01-26', 15, 7),
('Un chef-d''oeuvre du genre', '2024-01-27', 16, 7),
('Christian Bale parfait en Batman', '2024-01-28', 17, 7),
-- Pulp Fiction
('Dialogue incroyable de Tarantino', '2024-01-29', 18, 8),
('Film culte absolu', '2024-01-30', 19, 8),
('La bande-son est légendaire', '2024-02-01', 20, 8),
('Structure narrative brillante', '2024-02-02', 1, 8),
-- Fight Club
('Twist final incroyable', '2024-02-03', 2, 9),
('Brad Pitt au top', '2024-02-04', 3, 9),
('Un film qui marque les esprits', '2024-02-05', 4, 9),
-- The Matrix
('Révolutionnaire pour son époque', '2024-02-06', 5, 10),
('Les effets spéciaux sont incroyables', '2024-02-07', 6, 10),
('Keanu Reeves parfait en Neo', '2024-02-08', 7, 10),
('La pilule rouge ou la pilule bleue?', '2024-02-09', 8, 10),
-- Interstellar
('Visuellement époustouflant', '2024-02-10', 9, 11),
('La science-fiction à son meilleur', '2024-02-11', 10, 11),
('Musique de Hans Zimmer transcendante', '2024-02-12', 11, 11),
('Matthew McConaughey excellent', '2024-02-13', 12, 11),
-- Shawshank
('Le meilleur film de tous les temps', '2024-02-14', 13, 12),
('Une histoire d''amitié touchante', '2024-02-15', 14, 12),
('Morgan Freeman est parfait', '2024-02-16', 15, 12),
-- Forrest Gump
('Tom Hanks au sommet', '2024-02-17', 16, 13),
('Une histoire touchante', '2024-02-18', 17, 13),
('La vie est comme une boîte de chocolats', '2024-02-19', 18, 13),
-- The Godfather
('Le parrain de tous les films', '2024-02-20', 19, 14),
('Une saga familiale épique', '2024-02-21', 20, 14),
-- Goodfellas
('Scorsese au top', '2024-02-22', 1, 15),
('Ray Liotta incroyable', '2024-02-23', 2, 15),
-- Se7en
('Thriller sombre et captivant', '2024-02-24', 3, 16),
('La fin est choquante', '2024-02-25', 4, 16),
('Brad Pitt et Morgan Freeman : duo parfait', '2024-02-26', 5, 16),
-- Blade Runner 2049
('Suite digne de l''original', '2024-02-27', 6, 18),
('Visuellement magnifique', '2024-02-28', 7, 18),
('Ryan Gosling excellent', '2024-03-01', 8, 18),
-- Dune
('Adaptation fidèle et spectaculaire', '2024-03-02', 9, 19),
('Timothée Chalamet parfait en Paul', '2024-03-03', 10, 19),
('Visuellement époustouflant', '2024-03-04', 11, 19),
('Hans Zimmer encore une fois excellent', '2024-03-05', 12, 19),
('Meilleure que la première partie', '2024-03-06', 13, 20),
('Zendaya brille dans ce volet', '2024-03-07', 14, 20),
-- Avengers
('La conclusion parfaite de la saga Infinity', '2024-03-08', 15, 21),
('Tous les héros réunis, incroyable!', '2024-03-09', 16, 21),
('J''ai pleuré à la fin', '2024-03-10', 17, 21),
('Thanos est le meilleur méchant Marvel', '2024-03-11', 18, 22),
('Premier film MCU, le début d''une ère', '2024-03-12', 19, 23),
('Robert Downey Jr parfait en Tony Stark', '2024-03-13', 20, 23),
-- Barbie
('Film surprise de l''année 2023', '2024-03-14', 1, 25),
('Margot Robbie est parfaite', '2024-03-15', 2, 25),
('Ryan Gosling hilarant en Ken', '2024-03-16', 3, 25),
-- Oppenheimer
('Christopher Nolan encore une fois brillant', '2024-03-17', 4, 26),
('Cillian Murphy mérite l''Oscar', '2024-03-18', 5, 26),
('Film intense du début à la fin', '2024-03-19', 6, 26),
-- Breaking Bad
('Meilleure série de tous les temps', '2024-03-20', 7, 32),
('Walter White : personnage complexe fascinant', '2024-03-21', 8, 32),
('Bryan Cranston incroyable', '2024-03-22', 9, 33),
('La tension monte d''épisode en épisode', '2024-03-23', 10, 34),
('Gus Fring : méchant terrifiant', '2024-03-24', 11, 35),
('Finale parfaite', '2024-03-25', 12, 36),
-- Stranger Things
('Nostalgie des années 80', '2024-03-26', 13, 37),
('Eleven est un personnage génial', '2024-03-27', 14, 37),
('L''Upside Down me fait peur', '2024-03-28', 15, 38),
('Saison 3 : été 1985 parfait', '2024-03-29', 16, 39),
('Vecna est terrifiant', '2024-03-30', 17, 40),
-- Mandalorian
('Baby Yoda est adorable', '2024-04-01', 18, 41),
('Star Wars de retour en force', '2024-04-02', 19, 41),
('Pedro Pascal excellent', '2024-04-03', 20, 42),
-- Peaky Blinders
('Cillian Murphy hypnotisant', '2024-04-04', 1, 45),
('Thomas Shelby : personnage charismatique', '2024-04-05', 2, 45),
('L''ambiance des années 20 est parfaite', '2024-04-06', 3, 46),
-- House of the Dragon
('Digne successeur de Game of Thrones', '2024-04-07', 4, 49),
('Les dragons sont magnifiques', '2024-04-08', 5, 49),
('Guerre civile Targaryen captivante', '2024-04-09', 6, 50);

-- ═══════════════════════════════════════════════════════════
--                         PHOTOS
-- ═══════════════════════════════════════════════════════════

INSERT INTO photo (chemin, description_, id_utilisateur, id_oeuvre) VALUES
('/static/images/photo_1.jpeg', 'Affiche officielle', 1, 1),
('/static/images/photo_2.jpeg', 'Poster original Star Wars IV', 3, 2),
('/static/images/photo_3.jpg', 'Affiche saison 1', 2, 5),
('/static/images/photo_4.jpg', 'Batman face au Joker', 5, 7),
('/static/images/photo_5.jpg', 'Affiche culte Tarantino', 7, 8),
('/static/images/photo_6.jpg', 'Neo et la pilule rouge', 9, 10),
('/static/images/photo_7.jpg', 'Voyage spatial', 11, 11),
('/static/images/photo_8.jpg', 'Paul Atreides sur Arrakis', 13, 19),
('/static/images/photo_9.jpg', 'Tous les héros réunis', 15, 21),
('/static/images/photo_10.jpg', 'Barbie et Ken', 17, 25),
('/static/images/photo_11.jpeg', 'Portrait d Oppenheimer', 19, 26),
('/static/images/photo_12.jpeg', 'Walter White', 1, 32),
('/static/images/photo_13.jpeg', 'Eleven et ses amis', 3, 37),
('/static/images/photo_14.jpeg', 'Baby Yoda', 5, 41),
('/static/images/photo_15.jpeg', 'L Empire contre-attaque', 1, 3),
('/static/images/photo_16.jpg', 'Le Retour du Jedi', 1, 4),
('/static/images/photo_17.jpeg', 'Game of Thrones S2', 2, 6),
('/static/images/photo_18.jpeg', 'Brad Pitt et Edward Norton', 4, 9),
('/static/images/photo_19.jpeg', 'Prison Shawshank', 6, 12),
('/static/images/photo_20.jpeg', 'Forrest et sa boîte de chocolats', 7, 13),
('/static/images/photo_21.jpeg', 'La famille Corleone', 8, 14),
('/static/images/photo_22.jpeg', 'Ray Liotta Goodfellas', 9, 15),
('/static/images/photo_23.jpeg', 'Les 7 péchés capitaux', 10, 16),
('/static/images/photo_24.jpeg', 'Hannibal Lecter', 11, 17),
('/static/images/photo_25.jpeg', 'Officer K dans la ville', 12, 18),
('/static/images/photo_26.jpeg', 'Dune Partie Deux', 13, 20),
('/static/images/photo_27.jpeg', 'Thanos et les pierres', 14, 22),
('/static/images/photo_28.jpeg', 'Tony Stark premier armure', 15, 23),
('/static/images/photo_29.jpeg', 'Thor et Mjolnir', 16, 24),
('/static/images/photo_30.jpeg', 'Leonardo DiCaprio Wall Street', 17, 27),
('/static/images/photo_31.jpeg', 'Jack et Rose sur le Titanic', 18, 28),
('/static/images/photo_32.jpeg', 'La Communauté de l Anneau', 19, 29),
('/static/images/photo_33.jpeg', 'Les Deux Tours', 20, 30),
('/static/images/photo_34.jpeg', 'Le Retour du Roi', 1, 31),
('/static/images/photo_35.jpeg', 'Breaking Bad S2', 2, 33),
('/static/images/photo_36.jpeg', 'Breaking Bad S3', 3, 34),
('/static/images/photo_37.jpeg', 'Breaking Bad S4', 4, 35),
('/static/images/photo_38.jpeg', 'Breaking Bad S5 finale', 5, 36),
('/static/images/photo_39.jpeg', 'Stranger Things S2 Upside Down', 6, 38),
('/static/images/photo_40.jpeg', 'Stranger Things S3 été 1985', 7, 39),
('/static/images/photo_41.jpeg', 'Stranger Things S4 Vecna', 8, 40),
('/static/images/photo_42.jpeg', 'Mandalorian S2 aventures', 9, 42),
('/static/images/photo_43.jpeg', 'The Crown Elizabeth II', 10, 43),
('/static/images/photo_44.jpeg', 'The Crown années 60', 11, 44),
('/static/images/photo_45.jpeg', 'Peaky Blinders gang Birmingham', 12, 45),
('/static/images/photo_46.jpeg', 'Peaky Blinders S2 expansion', 13, 46),
('/static/images/photo_47.jpeg', 'Geralt et son épée', 14, 47),
('/static/images/photo_48.jpeg', 'The Witcher S2 Ciri', 15, 48),
('/static/images/photo_49.jpeg', 'House of the Dragon Targaryen', 16, 49),
('/static/images/photo_50.jpeg', 'Dragons en guerre', 17, 50);

-- ═══════════════════════════════════════════════════════════
--                         FAVORIS
-- ═══════════════════════════════════════════════════════════

INSERT INTO favoris VALUES
-- User 1
(1, 1, '2024-01-10'),  -- Inception
(1, 2, '2024-01-10'),  -- Star Wars IV
(1, 7, '2024-01-11'),  -- Dark Knight
(1, 10, '2024-01-12'), -- Matrix
(1, 26, '2024-01-13'), -- Oppenheimer
-- User 2
(2, 5, '2024-01-11'),  -- GoT S1
(2, 6, '2024-01-14'),  -- GoT S2
(2, 8, '2024-01-15'),  -- Pulp Fiction
(2, 32, '2024-01-16'), -- Breaking Bad S1
-- User 3
(3, 2, '2024-01-17'),  -- Star Wars IV
(3, 3, '2024-01-18'),  -- Star Wars V
(3, 4, '2024-01-19'),  -- Star Wars VI
(3, 41, '2024-01-20'), -- Mandalorian S1
-- User 4
(4, 2, '2024-01-12'),  -- Star Wars IV
(4, 21, '2024-01-21'), -- Avengers Endgame
(4, 22, '2024-01-22'), -- Avengers Infinity War
(4, 23, '2024-01-23'), -- Iron Man
-- User 5
(5, 1, '2024-01-13'),  -- Inception
(5, 11, '2024-01-24'), -- Interstellar
(5, 19, '2024-01-25'), -- Dune 1
(5, 20, '2024-01-26'), -- Dune 2
-- User 6
(6, 9, '2024-01-27'),  -- Fight Club
(6, 16, '2024-01-28'), -- Se7en
(6, 18, '2024-01-29'), -- Blade Runner 2049
-- User 7
(7, 12, '2024-01-30'), -- Shawshank
(7, 13, '2024-02-01'), -- Forrest Gump
(7, 14, '2024-02-02'), -- Godfather
-- User 8
(8, 37, '2024-02-03'), -- Stranger Things S1
(8, 38, '2024-02-04'), -- Stranger Things S2
(8, 39, '2024-02-05'), -- Stranger Things S3
(8, 40, '2024-02-06'), -- Stranger Things S4
-- User 9
(9, 10, '2024-02-07'), -- Matrix
(9, 18, '2024-02-08'), -- Blade Runner 2049
(9, 19, '2024-02-09'), -- Dune 1
-- User 10
(10, 25, '2024-02-10'), -- Barbie
(10, 27, '2024-02-11'), -- Wolf of Wall Street
(10, 28, '2024-02-12'), -- Titanic
-- User 11
(11, 29, '2024-02-13'), -- LOTR 1
(11, 30, '2024-02-14'), -- LOTR 2
(11, 31, '2024-02-15'), -- LOTR 3
-- User 12
(12, 45, '2024-02-16'), -- Peaky Blinders S1
(12, 46, '2024-02-17'), -- Peaky Blinders S2
-- User 13
(13, 49, '2024-02-18'), -- House of the Dragon S1
(13, 50, '2024-02-19'), -- House of the Dragon S2
(13, 5, '2024-02-20'),  -- GoT S1
-- User 14
(14, 21, '2024-02-21'), -- Avengers Endgame
(14, 23, '2024-02-22'), -- Iron Man
(14, 24, '2024-02-23'), -- Thor
-- User 15
(15, 7, '2024-02-24'),  -- Dark Knight
(15, 1, '2024-02-25'),  -- Inception
(15, 26, '2024-02-26'); -- Oppenheimer

-- ═══════════════════════════════════════════════════════════
--                    LIENS ENTRE OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO lien VALUES
-- Star Wars trilogie
(2, 3, 'suite'),
(3, 4, 'suite'),
-- Game of Thrones
(5, 6, 'suite'),
-- Dune
(19, 20, 'suite'),
-- Avengers
(22, 21, 'suite'),
(23, 22, 'préquel'),
-- Breaking Bad
(32, 33, 'suite'),
(33, 34, 'suite'),
(34, 35, 'suite'),
(35, 36, 'suite'),
-- Stranger Things
(37, 38, 'suite'),
(38, 39, 'suite'),
(39, 40, 'suite'),
-- Mandalorian
(41, 42, 'suite'),
-- The Crown
(43, 44, 'suite'),
-- Peaky Blinders
(45, 46, 'suite'),
-- The Witcher
(47, 48, 'suite'),
-- House of the Dragon
(49, 50, 'suite'),
(5, 49, 'préquel'),
-- LOTR
(29, 30, 'suite'),
(30, 31, 'suite'),
-- Nolan films
(1, 7, 'même réalisateur'),
(1, 11, 'même réalisateur'),
(7, 11, 'même réalisateur'),
-- Villeneuve films
(18, 19, 'même réalisateur');

-- ═══════════════════════════════════════════════════════════
--                         ÉPISODES
-- ═══════════════════════════════════════════════════════════

INSERT INTO episode (titre, num_ep, synopsie, id_oeuvre) VALUES
-- Game of Thrones S1 (id_oeuvre: 5)
('Winter Is Coming', 'S01E01', 'Ned Stark accepte de devenir Main du Roi', 5),
('The Kingsroad', 'S01E02', 'Voyage vers Port-Réal', 5),
('Lord Snow', 'S01E03', 'Jon Snow rejoint la Garde de Nuit', 5),
('Cripples, Bastards, and Broken Things', 'S01E04', 'Bran fait des rêves étranges', 5),
('The Wolf and the Lion', 'S01E05', 'Tensions entre Stark et Lannister', 5),
('A Golden Crown', 'S01E06', 'Viserys reçoit sa couronne d or', 5),
('You Win or You Die', 'S01E07', 'Ned découvre la vérité sur les Lannister', 5),
('The Pointy End', 'S01E08', 'Guerre entre les maisons', 5),
('Baelor', 'S01E09', 'Ned Stark face à son destin', 5),
('Fire and Blood', 'S01E10', 'Naissance des dragons', 5),
-- Game of Thrones S2 (id_oeuvre: 6)
('The North Remembers', 'S02E01', 'Début de la guerre des Cinq Rois', 6),
('The Night Lands', 'S02E02', 'Arya sur la route', 6),
('What Is Dead May Never Die', 'S02E03', 'Theon retourne aux îles de Fer', 6),
('Garden of Bones', 'S02E04', 'Horreurs de la guerre', 6),
('The Ghost of Harrenhal', 'S02E05', 'Renly assassiné', 6),
('The Old Gods and the New', 'S02E06', 'Theon prend Winterfell', 6),
('A Man Without Honor', 'S02E07', 'Jaime prisonnier', 6),
('The Prince of Winterfell', 'S02E08', 'Préparatifs de bataille', 6),
('Blackwater', 'S02E09', 'Bataille de la Néra', 6),
('Valar Morghulis', 'S02E10', 'Tous les hommes doivent mourir', 6),
-- Breaking Bad S1 (id_oeuvre: 32)
('Pilot', 'S01E01', 'Walter White diagnostiqué d un cancer', 32),
('Cat''s in the Bag', 'S01E02', 'Premier meurtre', 32),
('And the Bag''s in the River', 'S01E03', 'Walter face à un dilemme', 32),
('Cancer Man', 'S01E04', 'Walter annonce sa maladie', 32),
('Gray Matter', 'S01E05', 'Walter refuse l aide', 32),
('Crazy Handful of Nothin''', 'S01E06', 'Walter rencontre Tuco', 32),
('A No-Rough-Stuff-Type Deal', 'S01E07', 'Premier gros deal', 32),
-- Breaking Bad S2 (id_oeuvre: 33)
('Seven Thirty-Seven', 'S02E01', 'Confrontation avec Tuco', 33),
('Grilled', 'S02E02', 'Combat final contre Tuco', 33),
('Bit by a Dead Bee', 'S02E03', 'Retrouver la normalité', 33),
('Down', 'S02E04', 'Hank traumatisé', 33),
('Breakage', 'S02E05', 'Expansion du territoire', 33),
('Peekaboo', 'S02E06', 'Jesse face aux junkies', 33),
-- Stranger Things S1 (id_oeuvre: 37)
('Chapter One: The Vanishing of Will Byers', 'S01E01', 'Will disparaît mystérieusement', 37),
('Chapter Two: The Weirdo on Maple Street', 'S01E02', 'Découverte d Eleven', 37),
('Chapter Three: Holly, Jolly', 'S01E03', 'Recherches dans l Upside Down', 37),
('Chapter Four: The Body', 'S01E04', 'Fausses funérailles de Will', 37),
('Chapter Five: The Flea and the Acrobat', 'S01E05', 'Plan pour sauver Will', 37),
('Chapter Six: The Monster', 'S01E06', 'Le Demogorgon attaque', 37),
('Chapter Seven: The Bathtub', 'S01E07', 'Eleven cherche Will', 37),
('Chapter Eight: The Upside Down', 'S01E08', 'Mission de sauvetage finale', 37),
-- Stranger Things S2 (id_oeuvre: 38)
('Chapter One: MADMAX', 'S02E01', 'Nouvelle menace se profile', 38),
('Chapter Two: Trick or Treat, Freak', 'S02E02', 'Halloween à Hawkins', 38),
('Chapter Three: The Pollywog', 'S02E03', 'Dustin trouve un étrange animal', 38),
('Chapter Four: Will the Wise', 'S02E04', 'Will a des visions', 38),
('Chapter Five: Dig Dug', 'S02E05', 'Tunnels sous Hawkins', 38),
('Chapter Six: The Spy', 'S02E06', 'Will possédé', 38),
('Chapter Seven: The Lost Sister', 'S02E07', 'Passé d Eleven révélé', 38),
('Chapter Eight: The Mind Flayer', 'S02E08', 'Véritable menace identifiée', 38),
('Chapter Nine: The Gate', 'S02E09', 'Bataille finale', 38),
-- The Mandalorian S1 (id_oeuvre: 41)
('Chapter 1: The Mandalorian', 'S01E01', 'Mando reçoit une nouvelle mission', 41),
('Chapter 2: The Child', 'S01E02', 'Découverte de Baby Yoda', 41),
('Chapter 3: The Sin', 'S01E03', 'Dilemme moral de Mando', 41),
('Chapter 4: Sanctuary', 'S01E04', 'Village attaqué par des raiders', 41),
('Chapter 5: The Gunslinger', 'S01E05', 'Chasseur de primes sur Tatooine', 41),
('Chapter 6: The Prisoner', 'S01E06', 'Mission de libération', 41),
('Chapter 7: The Reckoning', 'S01E07', 'Confrontation avec Moff Gideon', 41),
('Chapter 8: Redemption', 'S01E08', 'Bataille finale saison 1', 41),
-- Peaky Blinders S1 (id_oeuvre: 45)
('Episode 1', 'S01E01', 'Retour de la guerre, gang des Peaky Blinders', 45),
('Episode 2', 'S01E02', 'Armes volées recherchées', 45),
('Episode 3', 'S01E03', 'Thomas face à l inspecteur Campbell', 45),
('Episode 4', 'S01E04', 'Expansion du gang', 45),
('Episode 5', 'S01E05', 'Alliance avec les gitans', 45),
('Episode 6', 'S01E06', 'Confrontation finale', 45),
-- House of the Dragon S1 (id_oeuvre: 49)
('The Heirs of the Dragon', 'S01E01', 'Succession Targaryen en question', 49),
('The Rogue Prince', 'S01E02', 'Daemon exilé', 49),
('Second of His Name', 'S01E03', 'Viserys choisit sa Main', 49),
('King of the Narrow Sea', 'S01E04', 'Rhaenyra grandit', 49),
('We Light the Way', 'S01E05', 'Mariage royal', 49),
('The Princess and the Queen', 'S01E06', 'Tensions familiales', 49),
('Driftmark', 'S01E07', 'Funérailles et révélations', 49),
('The Lord of the Tides', 'S01E08', 'Question de succession', 49),
('The Green Council', 'S01E09', 'Coup d État', 49),
('The Black Queen', 'S01E10', 'Début de la guerre civile', 49);

-- ═══════════════════════════════════════════════════════════
--                         NOTES
-- ═══════════════════════════════════════════════════════════

INSERT INTO note (id_utilisateur, id_oeuvre, note, date_note) VALUES
-- Notes pour Inception (id_oeuvre: 1)
(1, 1, 5, '2024-01-15'),
(2, 1, 5, '2024-01-20'),
(3, 1, 4, '2024-02-05'),
(4, 1, 5, '2024-02-10'),
(5, 1, 4, '2024-03-01'),
-- Notes pour The Dark Knight (id_oeuvre: 7)
(1, 7, 5, '2024-01-16'),
(2, 7, 5, '2024-01-22'),
(4, 7, 5, '2024-02-12'),
(6, 7, 4, '2024-03-05'),
(7, 7, 5, '2024-03-10'),
-- Notes pour Interstellar (id_oeuvre: 11)
(1, 11, 5, '2024-01-18'),
(3, 11, 4, '2024-02-08'),
(5, 11, 5, '2024-03-03'),
(8, 11, 4, '2024-03-15'),
-- Notes pour Game of Thrones S1 (id_oeuvre: 5)
(2, 5, 5, '2024-01-25'),
(3, 5, 4, '2024-02-06'),
(5, 5, 5, '2024-03-02'),
(9, 5, 5, '2024-03-20'),
(10, 5, 4, '2024-04-01'),
-- Notes pour Breaking Bad S1 (id_oeuvre: 32)
(4, 32, 5, '2024-02-15'),
(6, 32, 5, '2024-03-08'),
(7, 32, 5, '2024-03-12'),
(11, 32, 4, '2024-04-05'),
-- Notes pour Pulp Fiction (id_oeuvre: 13)
(3, 13, 5, '2024-02-10'),
(5, 13, 4, '2024-03-04'),
(12, 13, 5, '2024-04-10'),
(13, 13, 5, '2024-04-15'),
-- Notes pour Star Wars (id_oeuvre: 2)
(1, 2, 5, '2024-01-17'),
(8, 2, 4, '2024-03-16'),
(14, 2, 5, '2024-04-20'),
-- Notes pour The Shawshank Redemption (id_oeuvre: 16)
(5, 16, 5, '2024-03-05'),
(15, 16, 5, '2024-04-22'),
(16, 16, 5, '2024-05-01'),
-- Notes pour Avatar (id_oeuvre: 17)
(9, 17, 4, '2024-03-22'),
(10, 17, 3, '2024-04-02'),
(17, 17, 4, '2024-05-05'),
-- Notes pour Stranger Things S1 (id_oeuvre: 37)
(8, 37, 5, '2024-03-18'),
(18, 37, 4, '2024-05-10'),
(19, 37, 5, '2024-05-15'),
-- Notes supplémentaires variées
(11, 18, 5, '2024-04-06'),
(12, 19, 4, '2024-04-11'),
(13, 29, 5, '2024-04-16'),
(14, 30, 5, '2024-04-21'),
(15, 31, 4, '2024-04-23'),
(16, 41, 5, '2024-05-02'),
(17, 45, 4, '2024-05-06'),
(18, 49, 5, '2024-05-11'),
(19, 26, 4, '2024-05-16'),
(20, 28, 3, '2024-05-20');

-- ═══════════════════════════════════════════════════════════
--         ENRICHISSEMENT PREMIUM — DESCRIPTIONS DÉTAILLÉES
-- ═══════════════════════════════════════════════════════════

UPDATE oeuvre SET description_oeuvre = 'Dom Cobb est un voleur d''élite capable de s''infiltrer dans les rêves pour en extraire des secrets. Lorsqu''on lui propose d''implanter une idée dans l''esprit d''un héritier, il réunit une équipe pour l''impossible. Le film explore les frontières entre rêve et réalité avec une maîtrise technique et narrative époustouflante. Son final délibérément ambigu continue de diviser et de fasciner les spectateurs du monde entier.' WHERE id_oeuvre = 1;

UPDATE oeuvre SET description_oeuvre = 'Luke Skywalker rejoint la Rébellion pour combattre l''Empire Galactique et l''Étoile de la Mort. Guidé par Obi-Wan Kenobi et accompagné du contrebandier Han Solo, il découvre son destin dans la Force. Ce premier volet a révolutionné le cinéma de science-fiction et engendré l''une des sagas culturelles les plus influentes de l''histoire du 7e art.' WHERE id_oeuvre = 2;

UPDATE oeuvre SET description_oeuvre = 'L''Empire contre-attaque voit Luke Skywalker s''entraîner auprès du maître Yoda tandis que Han Solo et la Princesse Leia fuient les troupes impériales. La révélation finale de Darth Vader est l''un des moments les plus marquants du cinéma mondial. Considéré par beaucoup comme le meilleur épisode de la saga, il approfondit les personnages et assombrit le ton de la trilogie.' WHERE id_oeuvre = 3;

UPDATE oeuvre SET description_oeuvre = 'Dans ce dénouement de la trilogie originale, Luke affronte Darth Vader pour la dernière fois tandis que la Rébellion tente de détruire la seconde Étoile de la Mort. Le film réconcilie la saga sur les thèmes de la rédemption et du sacrifice familial. Une conclusion épique qui a ému des générations de fans à travers le monde.' WHERE id_oeuvre = 4;

UPDATE oeuvre SET description_oeuvre = 'La première saison installe sept grandes familles nobles se disputant le Trône de Fer de Westeros. Les intrigues politiques, les trahisons et les combats se succèdent dans un univers médiéval fantastique sombre et brutal. La chute de Ned Stark dans le final a choqué le monde entier et établi la série comme un monument de la télévision moderne.' WHERE id_oeuvre = 5;

UPDATE oeuvre SET description_oeuvre = 'La Guerre des Cinq Rois s''intensifie, chacun réclamant le Trône de Fer à Westeros. Jon Snow progresse dans la Garde de Nuit, Daenerys grandit en chef de guerre et Tyrion devient Main du Roi. La Bataille de la Néra est l''un des épisodes les plus spectaculaires de la télévision, alliant effets visuels grandioses et tension dramatique.' WHERE id_oeuvre = 6;

UPDATE oeuvre SET description_oeuvre = 'Batman doit affronter le Joker, criminel chaotique qui entend prouver que tout homme peut sombrer dans la folie. Christopher Nolan élève le film de super-héros au rang d''étude psychologique et morale sur le bien et le mal. La performance de Heath Ledger, oscarisée à titre posthume, reste l''une des plus mémorables de l''histoire du cinéma.' WHERE id_oeuvre = 7;

UPDATE oeuvre SET description_oeuvre = 'À travers une narration non linéaire virtuose, Tarantino entremêle les histoires de criminels, de gangsters et de braqueurs à Los Angeles. Ses dialogues devenus cultes, sa bande-son iconique et ses retournements de situation inattendus en font un film fondateur du cinéma indépendant des années 90. Un chef-d''œuvre absolu qui a marqué une génération entière.' WHERE id_oeuvre = 8;

UPDATE oeuvre SET description_oeuvre = 'Un homme insomniaque rencontre Tyler Durden et fonde avec lui un club de combat clandestin qui devient rapidement un mouvement révolutionnaire. David Fincher signe un film culte sur la masculinité toxique, le consumérisme et la crise d''identité moderne. Le twist final a bouleversé le cinéma et la façon dont les spectateurs appréhendent un récit à la première personne.' WHERE id_oeuvre = 9;

UPDATE oeuvre SET description_oeuvre = 'Thomas Anderson, hacker connu sous le nom de Neo, découvre que la réalité est en fait une simulation informatique appelée la Matrice. Guidé par Morpheus et Trinity, il doit embrasser son destin de l''Élu pour libérer l''humanité. Révolutionnaire à sa sortie pour ses effets "bullet time", ce film de science-fiction philosophique questionne la nature de la réalité et du libre arbitre.' WHERE id_oeuvre = 10;

UPDATE oeuvre SET description_oeuvre = 'Dans un futur où la Terre est mourante, un ex-astronaute et agriculteur doit traverser un trou de ver pour trouver une nouvelle planète habitable. Nolan mêle hard science et émotion familiale pure dans un voyage cosmique qui traverse le temps et les dimensions. La scène sur la planète océan et le retour dans la station sont parmi les moments les plus bouleversants du cinéma de science-fiction.' WHERE id_oeuvre = 11;

UPDATE oeuvre SET description_oeuvre = 'Andy Dufresne, banquier condamné à tort pour le meurtre de sa femme, purge sa peine à la prison de Shawshank où il lie une amitié profonde avec le trafiquant Red. À travers l''amitié, l''espoir et la résilience, cette adaptation de Stephen King transcende le genre carcéral pour devenir une méditation universelle sur la dignité humaine. Classé numéro un sur IMDb depuis plus de vingt ans.' WHERE id_oeuvre = 12;

UPDATE oeuvre SET description_oeuvre = 'Forrest Gump, homme au QI limité mais au cœur immense, traverse involontairement les grands moments de l''histoire américaine des années 50 aux années 80. Tom Hanks livre une performance inoubliable dans ce conte optimiste sur le destin, l''amour et la persévérance. "La vie, c''est comme une boîte de chocolats" est devenu l''une des citations les plus célèbres du cinéma mondial.' WHERE id_oeuvre = 13;

UPDATE oeuvre SET description_oeuvre = 'Vito Corleone, parrain de la famille mafieuse la plus puissante de New York, transfère progressivement le pouvoir à son fils Michael après avoir été assassiné. Francis Ford Coppola signe une fresque épique sur la famille, le pouvoir et la corruption morale. Régulièrement classé parmi les deux ou trois meilleurs films jamais réalisés, avec une distribution d''acteurs légendaires.' WHERE id_oeuvre = 14;

UPDATE oeuvre SET description_oeuvre = 'Henry Hill, issu d''une famille modeste, rêve d''intégrer la mafia new-yorkaise et vit pendant trois décennies de crimes et de trahisons aux côtés de ses amis gangsters. Scorsese filme cette épopée criminelle avec une énergie électrisante et un sens du détail historique remarquable. Sa narration en voix off et sa bande-son rock en font un film d''une modernité intacte.' WHERE id_oeuvre = 15;

UPDATE oeuvre SET description_oeuvre = 'Deux détectives de Los Angeles traquent un tueur en série qui met en scène ses meurtres comme incarnation des sept péchés capitaux. Fincher installe une atmosphère de désespoir pluvieux et claustrophobique qui ne se dissipe jamais. La fin déchirante avec "What''s in the box?" est entrée dans la légende du thriller hollywoodien pour son audace absolue.' WHERE id_oeuvre = 16;

UPDATE oeuvre SET description_oeuvre = 'Clarice Starling, jeune agent du FBI, doit solliciter l''aide du psychiatre cannibale Hannibal Lecter pour traquer un autre tueur en série. L''échange intellectuel électrisant entre les deux personnages, joués par Jodie Foster et Anthony Hopkins, est l''une des confrontations les plus mémorables du cinéma. Premier film de genre à remporter l''Oscar du meilleur film depuis Silence of the Lambs.' WHERE id_oeuvre = 17;

UPDATE oeuvre SET description_oeuvre = 'Dans un Los Angeles futuriste de 2049, le policier K doit retrouver un mystérieux replicant disparu depuis des décennies. Denis Villeneuve signe une suite digne du classique original de Ridley Scott, avec une photographie de Roger Deakins oscarisée d''une beauté hypnotique. Film ambitieux et contemplatif sur l''identité, la mémoire et ce qui définit l''humanité.' WHERE id_oeuvre = 18;

UPDATE oeuvre SET description_oeuvre = 'Paul Atreides, jeune héritier d''une noble famille, est envoyé sur Arrakis, planète désertique productrice de la précieuse Épice. Villeneuve réalise une adaptation fidèle et grandiose du roman culte de Frank Herbert, avec un casting époustouflant emmené par Timothée Chalamet et Zendaya. La photographie des dunes et la musique de Hans Zimmer créent une expérience cinématographique unique.' WHERE id_oeuvre = 19;

UPDATE oeuvre SET description_oeuvre = 'Paul Atreides conduit les Fremen dans leur rébellion contre l''Empire tandis que sa relation avec Chani s''approfondit. Cette deuxième partie surpasse la première en action, en émotion et en ambition narrative, s''imposant comme l''un des blockbusters les plus intellectuellement stimulants de la décennie. La transformation de Paul en messager fanatique est fascinante et troublante.' WHERE id_oeuvre = 20;

UPDATE oeuvre SET description_oeuvre = 'Cinq ans après la claquement de doigts de Thanos, les Avengers survivants tentent de voyager dans le temps pour récupérer les Pierres d''Infinité. Cette conclusion épique de vingt-deux films réunit tous les héros Marvel pour une bataille finale spectaculaire. La scène de portails et le sacrifice de Tony Stark ont ému des millions de spectateurs dans le monde entier.' WHERE id_oeuvre = 21;

UPDATE oeuvre SET description_oeuvre = 'Thanos, titan fou, cherche à rassembler les six Pierres d''Infinité pour éliminer la moitié de la vie dans l''univers. Les Avengers, éparpillés sur plusieurs planètes, tentent désespérément de l''en empêcher. Le final choc où Thanos claque des doigts et fait disparaître la moitié des héros est l''un des moments les plus audacieux jamais vus dans un film de super-héros.' WHERE id_oeuvre = 22;

UPDATE oeuvre SET description_oeuvre = 'Tony Stark, milliardaire génie et marchand d''armes, est capturé par des terroristes et fabrique une armure pour s''échapper. De retour aux États-Unis, il perfectionne l''armure pour devenir Iron Man et protéger le monde. Ce film fondateur du Marvel Cinematic Universe a lancé l''un des phénomènes culturels les plus durables de l''histoire du cinéma.' WHERE id_oeuvre = 23;

UPDATE oeuvre SET description_oeuvre = 'Thor, dieu du tonnerre d''Asgard, est banni sur Terre par son père Odin pour son arrogance. Privé de ses pouvoirs, il apprend l''humilité parmi les humains tandis que son frère Loki complote pour prendre le pouvoir. Chris Hemsworth incarne avec charisme le dieu guerrier dans ce premier volet aux accents mythologiques et cosmiques.' WHERE id_oeuvre = 24;

UPDATE oeuvre SET description_oeuvre = 'Barbie vit dans l''utopie parfaite de Barbieland jusqu''au jour où des pensées existentielles perturbent sa vie idéale et la forcent à explorer le monde réel. Greta Gerwig signe une satire féministe brillante et drôle, emballée dans une esthétique rose flamboyante, qui a fracassé tous les records au box-office de l''été 2023. Margot Robbie et Ryan Gosling sont tous deux inoubliables.' WHERE id_oeuvre = 25;

UPDATE oeuvre SET description_oeuvre = 'J. Robert Oppenheimer, physicien théoricien, dirige le Projet Manhattan pour développer la première bombe atomique pendant la Seconde Guerre mondiale. Nolan alterne entre la création de l''arme la plus destructrice de l''histoire et le procès kafkaïen qui brisera ensuite le savant. Cillian Murphy livre une performance magistrale dans ce film dense et moralement vertigineux.' WHERE id_oeuvre = 26;

UPDATE oeuvre SET description_oeuvre = 'Jordan Belfort fonde une firme de courtage à Wall Street et s''enrichit scandaleusement grâce à la fraude financière, la corruption et les excès en tout genre. Scorsese filme cette débauche avec une énergie dionysiaques irrésistible sur trois heures qui passent comme un tourbillon. DiCaprio est au sommet de son art dans ce portrait édifiant de la cupidité américaine.' WHERE id_oeuvre = 27;

UPDATE oeuvre SET description_oeuvre = 'Jack Dawson, jeune artiste sans le sou, gagne un billet pour la traversée inaugurale du Titanic et tombe éperdument amoureux de Rose, jeune aristocrate fiancée à un riche prétendant. James Cameron tisse une histoire d''amour inoubliable sur fond de la plus célèbre catastrophe maritime de l''Histoire. Le film reste l''une des œuvres les plus rentables et les plus pleurées de tous les temps.' WHERE id_oeuvre = 28;

UPDATE oeuvre SET description_oeuvre = 'Frodo Baggins, jeune Hobbit de la Comté, reçoit l''Anneau Unique et forme une Communauté avec elfes, nains et humains pour le détruire dans les feux de la Montagne du Destin. Peter Jackson adapte le roman culte de Tolkien avec une magnificence visuelle inégalée. Ce premier volet a redéfini les standards du cinéma fantastique épique et a inauguré l''une des trilogies les plus acclamées.' WHERE id_oeuvre = 29;

UPDATE oeuvre SET description_oeuvre = 'La Communauté dispersée, Frodo et Sam poursuivent seuls leur route vers le Mordor, guidés par la créature ambiguë Gollum. Aragorn, Legolas et Gimli combattent pour empêcher Sauron de dominer le monde. La bataille du Gouffre de Helm est un monument des effets spéciaux et de la mise en scène épique.' WHERE id_oeuvre = 30;

UPDATE oeuvre SET description_oeuvre = 'Le Retour du Roi marque l''apothéose de la trilogie : la bataille des Champs du Pelennor, le siège de Minas Tirith et la destruction finale de l''Anneau. Peter Jackson offre une conclusion triomphale, émotionnellement dévastatrice, qui a raflé onze Oscars dont celui du meilleur film. Un chef-d''œuvre du cinéma fantastique qui ne vieillit pas.' WHERE id_oeuvre = 31;

UPDATE oeuvre SET description_oeuvre = 'Walter White, professeur de chimie atteint d''un cancer du poumon, décide de cuisiner de la méthamphétamine pour assurer l''avenir de sa famille. Il s''associe à son ancien élève Jesse Pinkman et découvre une aptitude troublante pour le crime. La série installe dès sa première saison un portrait fascinant de la transformation morale d''un homme ordinaire en criminel.' WHERE id_oeuvre = 32;

UPDATE oeuvre SET description_oeuvre = 'Walter et Jesse s''associent avec le distributeur Saul Goodman pour écouler leur produit de qualité exceptionnelle. La tension monte à mesure que l''empire de Walter grandit et que les conséquences de ses choix s''accumulent dangereusement. Bryan Cranston incarne ici la rupture définitive de Mr. White avec son ancienne identité morale.' WHERE id_oeuvre = 33;

UPDATE oeuvre SET description_oeuvre = 'Walter White entre en conflit direct avec Gus Fring, distributeur méthodique et impitoyable qui gère un empire de drogue sous couverture d''une chaîne de fast-food. La tension intellectuelle entre les deux adversaires redéfinit les codes du thriller télévisé. Jonathan Banks en Mike Ehrmantraut émerge comme l''un des personnages secondaires les plus aimés de la série.' WHERE id_oeuvre = 34;

UPDATE oeuvre SET description_oeuvre = 'La confrontation finale entre Walter et Gus Fring monte à son paroxysme dans une quatrième saison parfaitement construite. L''assassinat de Gus dans un EHPAD est l''une des scènes les plus choquantes et mémorables de la télévision. La série confirme son statut de meilleure série américaine de son époque.' WHERE id_oeuvre = 35;

UPDATE oeuvre SET description_oeuvre = 'Dans la saison finale, Walter White tente de protéger sa famille et de récupérer son argent volé tandis que les autorités resserrent l''étau. Le final "Felina" offre à chaque personnage une conclusion parfaitement méritée, dans un dénouement qui a fait l''unanimité critique. Breaking Bad se conclut comme la meilleure série de l''histoire selon de nombreux palmarès.' WHERE id_oeuvre = 36;

UPDATE oeuvre SET description_oeuvre = 'Dans la petite ville de Hawkins, Indiana, la disparition mystérieuse de Will Byers révèle l''existence d''une dimension parallèle terrifiante appelée l''Upside Down. Ses amis Mike, Dustin et Lucas rencontrent Eleven, fillette aux pouvoirs télékinésiques fuguée d''un laboratoire secret. La série mêle horreur nostalgique, références aux années 80 et amitié touchante dans un cocktail addictif.' WHERE id_oeuvre = 37;

UPDATE oeuvre SET description_oeuvre = 'Will Byers est de retour, mais hanté par des visions de l''Upside Down et possédé par le Mind Flayer. Eleven explore son passé en partant seule tandis que ses amis font face à de nouveaux monstres. La série enrichit son univers et ses personnages tout en conservant sa magie nostalgique des années 80.' WHERE id_oeuvre = 38;

UPDATE oeuvre SET description_oeuvre = 'L''été 1985 à Hawkins voit le gang grandir, s''éloigner et se retrouver face à une nouvelle menace tentaculaire sous le centre commercial. Steve et Robin deviennent le duo comique le plus attachant de la série. La saison la plus légère en ton cache une profondeur émotionnelle inédite, notamment dans sa conclusion.' WHERE id_oeuvre = 39;

UPDATE oeuvre SET description_oeuvre = 'Les héros de Hawkins, maintenant séparés par l''exil d''Eleven, font face à Vecna, un ennemi venu de l''Upside Down qui attaque les traumatismes psychologiques. La saison la plus sombre et la plus ambitieuse de la série, avec des scènes de visages d''horreur pure et un épisode de deux heures remarquable. Kate Bush rentre dans la culture populaire avec le sublime Running Up That Hill.' WHERE id_oeuvre = 40;

UPDATE oeuvre SET description_oeuvre = 'Din Djarin, Mandalorien chasseur de primes, reçoit une mission mystérieuse et découvre que sa cible est Grogu, un enfant de l''espèce de Yoda aux pouvoirs étonnants. La série Star Wars sur Disney+ a ravi les fans avec son atmosphère western spatial intimiste. Pedro Pascal insuffle une humanité touchante à son personnage au visage constamment masqué.' WHERE id_oeuvre = 41;

UPDATE oeuvre SET description_oeuvre = 'Mando et Grogu poursuivent leur quête pour retrouver les Jedi, croisant des personnages iconiques de l''univers Star Wars. La saison accueille des guests explosifs et offre des révélations attendues sur la destinée de Grogu. L''épisode final, émouvant et spectaculaire, est l''un des meilleurs de la franchise télévisée Star Wars.' WHERE id_oeuvre = 42;

UPDATE oeuvre SET description_oeuvre = 'The Crown retrace le règne d''Elizabeth II depuis son mariage avec le Prince Philip jusqu''aux premières années de son règne. La série Netflix mêle avec un luxe de détails la vie privée de la famille royale et les grands événements politiques de l''après-guerre. Claire Foy, puis Olivia Colman, incarnent la reine avec une maîtrise et une subtilité remarquables.' WHERE id_oeuvre = 43;

UPDATE oeuvre SET description_oeuvre = 'La deuxième saison suit Elizabeth II à travers les années 60, entre la crise de Cuba, l''essor des Beatles et les tensions conjugales avec Philip. Les intrigues autour de la Princesse Margaret et de son amour impossible ajoutent une dimension romantique poignante. La série continue d''exceller dans son portrait intime d''une famille royale prise entre devoir et bonheur personnel.' WHERE id_oeuvre = 44;

UPDATE oeuvre SET description_oeuvre = 'Thomas Shelby et les Peaky Blinders, gang de Birmingham sorti de la Première Guerre mondiale, étendent leur empire criminel tout en faisant face à l''inspecteur Campbell envoyé par le gouvernement. Steven Knight crée un univers visuel et sonore unique, mêlant musique moderne et décors de l''Angleterre industrielle des années 20. Cillian Murphy est magnétique dans ce rôle qui l''a consacré.' WHERE id_oeuvre = 45;

UPDATE oeuvre SET description_oeuvre = 'Thomas Shelby consolide son empire à Birmingham et commence à tisser des alliances avec la politique nationale. La saison approfondit les rivalités familiales et introduit des antagonistes de taille. L''ambiance poisseuse et la photographie désaturée du Midlands anglais s''affirment comme la marque visuelle irremplaçable de la série.' WHERE id_oeuvre = 46;

UPDATE oeuvre SET description_oeuvre = 'Geralt de Riv, sorceleur chasseur de monstres au passé mystérieux, parcourt un continent médiéval fantastique en quête de sens. La série Netflix adapte les romans de l''auteur polonais Andrzej Sapkowski avec des effets spéciaux soignés et une narration non linéaire. Henry Cavill incarne Geralt avec une conviction physique et une profondeur inattendue.' WHERE id_oeuvre = 47;

UPDATE oeuvre SET description_oeuvre = 'Geralt prend Ciri sous son aile pour la protéger des forces qui la traquent à travers le Continent. La relation père-fille entre Geralt et Ciri devient le cœur émotionnel de cette deuxième saison plus linéaire et accessible. La série consolide son univers et prépare les grands conflits à venir entre humains, elfes et monstres.' WHERE id_oeuvre = 48;

UPDATE oeuvre SET description_oeuvre = 'Deux cents ans avant Game of Thrones, les Targaryen gouvernent Westeros jusqu''à ce qu''une crise de succession déchire la famille royale entre Rhaenyra et Aegon. La série prend le temps d''installer une galerie de personnages complexes dont certains traversent plusieurs décennies. Les dragons, nombreux et magnifiques, redonnent au monde de Westeros son souffle épique.' WHERE id_oeuvre = 49;

UPDATE oeuvre SET description_oeuvre = 'La guerre civile entre les partisans de Rhaenyra et ceux d''Aegon éclate dans un bain de sang fratricide. La deuxième saison monte en intensité dramatique et livre des batailles de dragons absolument stupéfiantes. Les enjeux dynastiques complexes et les retournements de situation fidèles à la tradition George R.R. Martin combleront les fans de la saga.' WHERE id_oeuvre = 50;

-- ═══════════════════════════════════════════════════════════
--         DEUX NOUVEAUX ARTISTES (réalisateurs)
-- ═══════════════════════════════════════════════════════════

INSERT INTO artiste (nom, prenom, date_naissance, biographie) VALUES
('Chazelle', 'Damien', '1985-01-19', 'Réalisateur américain prodige, oscarisé à 32 ans pour La La Land, passionné de jazz et de musique.'),
('Phillips', 'Todd', '1969-04-20', 'Réalisateur américain, connu pour la trilogie Very Bad Trip, révélé au grand public avec Joker en 2019.');

-- ═══════════════════════════════════════════════════════════
--         TROIS NOUVEAUX PERSONNAGES
-- ═══════════════════════════════════════════════════════════

INSERT INTO personnage (libelle) VALUES
('Sebastian Wilder'),
('Mia Dolan'),
('Arthur Fleck / Joker');

-- ═══════════════════════════════════════════════════════════
--         DEUX NOUVELLES OEUVRES (IDs 51 et 52)
-- ═══════════════════════════════════════════════════════════

INSERT INTO oeuvre (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre) VALUES
('La La Land', NULL, 'film', '2016-12-09', 'Sébastian, pianiste de jazz idéaliste, et Mia, actrice en devenir, se rencontrent à Los Angeles et tombent amoureux tout en poursuivant leurs rêves artistiques. Damien Chazelle signe une comédie musicale visuellement somptueuse qui rend hommage à Hollywood classique tout en questionnant le prix de l''ambition et des compromis amoureux. Ryan Gosling et Emma Stone sont électrisants ensemble dans un film qui a remporté six Oscars dont celui du meilleur réalisateur.'),
('Joker', NULL, 'film', '2019-10-04', 'Arthur Fleck, clown misérable et marginalisé de Gotham City, voit sa santé mentale se dégrader progressivement sous le poids des humiliations sociales jusqu''à sa métamorphose en Joker. Todd Phillips transforme le film de super-héros en étude psychologique glaçante et en critique sociale acérée de l''abandon des plus vulnérables. Joaquin Phoenix livre une performance physique et émotionnelle stupéfiante qui lui a valu l''Oscar du meilleur acteur.');

-- ═══════════════════════════════════════════════════════════
--         PHOTOS POUR LES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO photo (chemin, description_, id_utilisateur, id_oeuvre) VALUES
('/static/images/photo_51.jpeg', 'Affiche officielle La La Land', 18, 51),
('/static/images/photo_52.jpeg', 'Affiche officielle Joker', 19, 52);

-- ═══════════════════════════════════════════════════════════
--         GENRES DES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO appartient VALUES
(51, 'Musical'),
(51, 'Romance'),
(51, 'Drame'),
(52, 'Drame'),
(52, 'Crime'),
(52, 'Thriller');

-- ═══════════════════════════════════════════════════════════
--         RÉALISATEURS DES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════
-- Artiste 41 = Chazelle, Damien | Artiste 42 = Phillips, Todd

INSERT INTO realise VALUES
(41, 51),  -- Chazelle — La La Land
(42, 52);  -- Phillips — Joker

-- ═══════════════════════════════════════════════════════════
--         CASTING DES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════
-- Personnage 59 = Sebastian Wilder | 60 = Mia Dolan | 61 = Arthur Fleck / Joker
-- Artiste 17 = Gosling | 18 = Stone | 19 = Phoenix

INSERT INTO joue VALUES
(17, 51, 59),  -- Ryan Gosling — Sebastian — La La Land
(18, 51, 60),  -- Emma Stone — Mia — La La Land
(19, 52, 61);  -- Joaquin Phoenix — Arthur Fleck / Joker

-- ═══════════════════════════════════════════════════════════
--         COMMENTAIRES POUR LES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO commentaire (contenu, date_commentaire, id_utilisateur, id_oeuvre) VALUES
-- La La Land (oeuvre 51)
('Visuellement magnifique, une ode à Hollywood et au jazz', '2024-06-01', 1, 51),
('Ryan Gosling et Emma Stone sont parfaits ensemble', '2024-06-02', 3, 51),
('La fin m''a brisé le cœur, inoubliable', '2024-06-03', 5, 51),
('La meilleure comédie musicale moderne, sans hésitation', '2024-06-04', 7, 51),
('La photographie de Linus Sandgren est à couper le souffle', '2024-06-05', 9, 51),
-- Joker (oeuvre 52)
('Joaquin Phoenix est simplement phénoménal', '2024-06-06', 2, 52),
('Un film de super-héros qui n''est pas un film de super-héros', '2024-06-07', 4, 52),
('Glaçant et bouleversant, difficile à oublier', '2024-06-08', 6, 52),
('La scène d''escalier avec Purple Rain est un chef-d''œuvre', '2024-06-09', 8, 52),
('Critique sociale puissante déguisée en film de comics', '2024-06-10', 10, 52);

-- ═══════════════════════════════════════════════════════════
--         NOTES POUR LES NOUVELLES OEUVRES
-- ═══════════════════════════════════════════════════════════

INSERT INTO note (id_utilisateur, id_oeuvre, note, date_note) VALUES
(1, 51, 5, '2024-06-01'),
(3, 51, 5, '2024-06-02'),
(5, 51, 4, '2024-06-03'),
(7, 51, 5, '2024-06-04'),
(9, 51, 4, '2024-06-05'),
(11, 51, 5, '2024-06-06'),
(2, 52, 5, '2024-06-07'),
(4, 52, 5, '2024-06-08'),
(6, 52, 4, '2024-06-09'),
(8, 52, 5, '2024-06-10'),
(10, 52, 4, '2024-06-11'),
(12, 52, 5, '2024-06-12');

-- ═══════════════════════════════════════════════════════════
--         FAVORIS POUR LES NOUVELLES OEUVRES + USERS 16-20
-- ═══════════════════════════════════════════════════════════

INSERT INTO favoris VALUES
(1, 51, '2024-06-01'),
(3, 51, '2024-06-02'),
(5, 51, '2024-06-03'),
(2, 52, '2024-06-04'),
(4, 52, '2024-06-05'),
(16, 1, '2024-06-06'),   -- User 16 ajoute Inception
(16, 7, '2024-06-07'),   -- User 16 ajoute Dark Knight
(16, 11, '2024-06-08'),  -- User 16 ajoute Interstellar
(17, 10, '2024-06-09'),  -- User 17 ajoute Matrix
(17, 8, '2024-06-10'),   -- User 17 ajoute Pulp Fiction
(17, 9, '2024-06-11'),   -- User 17 ajoute Fight Club
(18, 19, '2024-06-12'),  -- User 18 ajoute Dune 1
(18, 20, '2024-06-13'),  -- User 18 ajoute Dune 2
(18, 26, '2024-06-14'),  -- User 18 ajoute Oppenheimer
(19, 32, '2024-06-15'),  -- User 19 ajoute BB S1
(19, 36, '2024-06-16'),  -- User 19 ajoute BB S5
(19, 51, '2024-06-17'),  -- User 19 ajoute La La Land
(20, 52, '2024-06-18'),  -- User 20 ajoute Joker
(20, 14, '2024-06-19'),  -- User 20 ajoute Godfather
(20, 15, '2024-06-20');  -- User 20 ajoute Goodfellas

-- ═══════════════════════════════════════════════════════════
--         VOTES SUR COMMENTAIRES (note_commentaire)
-- ═══════════════════════════════════════════════════════════
-- Rappel: PRIMARY KEY (id_utilisateur, id_commentaire)
-- Commentaire 1 (Inception) écrit par user 1 → votes d'autres users
-- Commentaire 2 (Inception) écrit par user 2 → votes d'autres users
-- ...

INSERT INTO note_commentaire (id_utilisateur, id_commentaire, utile) VALUES
-- Inception (comments 1-5)
(2, 1, true), (4, 1, true), (6, 1, true), (8, 1, true), (10, 1, true),
(1, 2, true), (3, 2, true), (5, 2, true), (7, 2, true),
(2, 3, true), (4, 3, true), (6, 3, false),
(1, 4, true), (3, 4, true),
(2, 5, true), (4, 5, true), (6, 5, true),
-- The Dark Knight (comments 19-22)
(1, 19, true), (3, 19, true), (5, 19, true), (7, 19, true), (9, 19, true),
(2, 20, true), (4, 20, true), (6, 20, true), (8, 20, true),
(1, 21, true), (3, 21, true), (5, 21, false),
(2, 22, true), (4, 22, true), (6, 22, true),
-- Interstellar (comments 34-37)
(1, 34, true), (2, 34, true), (4, 34, true), (6, 34, true),
(1, 35, true), (3, 35, true), (5, 35, true),
(2, 36, true), (4, 36, true),
(1, 37, true), (3, 37, true), (5, 37, false),
-- Dune (comments 54-57)
(1, 54, true), (2, 54, true), (3, 54, true), (4, 54, true),
(1, 55, true), (2, 55, true), (3, 55, true),
(1, 56, true), (2, 56, true),
(3, 57, true), (4, 57, true), (5, 57, false),
-- Breaking Bad (comments 72-73)
(1, 72, true), (2, 72, true), (3, 72, true), (4, 72, true), (5, 72, true),
(1, 73, true), (2, 73, true), (3, 73, true),
-- La La Land (comments 92-96, IDs calculés: 92-96)
(3, 92, true), (4, 92, true), (5, 92, true),
(1, 93, true), (4, 93, true), (6, 93, true),
(1, 94, true), (3, 94, true), (6, 94, true),
(2, 95, true), (4, 95, true),
(2, 96, true), (4, 96, true), (6, 96, true),
-- Joker (comments 97-101)
(1, 97, true), (3, 97, true), (5, 97, true), (7, 97, true),
(1, 98, true), (3, 98, true), (5, 98, true),
(1, 99, true), (3, 99, true), (7, 99, true),
(2, 100, true), (4, 100, true),
(2, 101, true), (4, 101, true), (6, 101, true);

-- ═══════════════════════════════════════════════════════════
--         LIENS ENTRE NOUVELLES OEUVRES ET EXISTANTES
-- ═══════════════════════════════════════════════════════════

INSERT INTO lien VALUES
(7, 52, 'même univers'),  -- Dark Knight ↔ Joker (univers DC)
(52, 7, 'même univers');  -- Joker ↔ Dark Knight
