-- ============================================================
-- ENRICHISSEMENT DES DONNÉES — CINÉFAN
-- À exécuter après dump.sql :
--   psql -U postgres -d cinefan -f dump.sql
--   psql -U postgres -d cinefan -f data_enrichissement.sql
--
-- Note : pour tester la connexion, créez un compte via /inscription
-- ============================================================


-- ------------------------------------------------------------------
-- CATÉGORIES SUPPLÉMENTAIRES
-- ------------------------------------------------------------------
INSERT INTO categorie VALUES
('Action'),
('Thriller'),
('Crime'),
('Animation')
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------
-- ARTISTES (IDs auto : 6 → 14)
-- ------------------------------------------------------------------
INSERT INTO artiste (nom, prenom, date_naissance, biographie) VALUES
('Nolan',       'Christopher', '1970-07-30', 'Réalisateur britannique, auteur de The Dark Knight, Inception et Interstellar.'),
('Bale',        'Christian',   '1974-01-30', 'Acteur gallois, connu pour Batman Begins, The Machinist et American Psycho.'),
('Cranston',    'Bryan',       '1956-03-07', 'Acteur américain, inoubliable en Walter White / Heisenberg dans Breaking Bad.'),
('Paul',        'Aaron',       '1979-08-27', 'Acteur américain, révélé par le rôle de Jesse Pinkman dans Breaking Bad.'),
('Reeves',      'Keanu',       '1964-09-02', 'Acteur canado-américain, star de The Matrix et de la saga John Wick.'),
('Jackson',     'Samuel L.',   '1948-12-21', 'Acteur américain, figure incontournable de Pulp Fiction et du MCU.'),
('Tarantino',   'Quentin',     '1963-03-27', 'Réalisateur américain, auteur de Pulp Fiction, Kill Bill et Inglourious Basterds.'),
('Coppola',     'Francis Ford','1939-04-07', 'Réalisateur américain, auteur du Parrain et d Apocalypse Now.'),
('Brando',      'Marlon',      '1924-04-03', 'Légende du cinéma américain, inoubliable en Vito Corleone dans Le Parrain.');
-- artiste_id attendus : 6=Nolan, 7=Bale, 8=Cranston, 9=Paul,
--                       10=Reeves, 11=Jackson, 12=Tarantino, 13=Coppola, 14=Brando


-- ------------------------------------------------------------------
-- ŒUVRES (IDs auto : 7 → 14)
-- ------------------------------------------------------------------
INSERT INTO oeuvre (titre, numero_volet_saison, type_oeuvre, date_creation, description_oeuvre) VALUES
('The Dark Knight',  NULL, 'film',  '2008-07-18', 'Le Chevalier Noir affronte le Joker dans une Gotham City plongée dans le chaos.'),
('Interstellar',     NULL, 'film',  '2014-11-05', 'Un groupe d astronautes traverse un trou de ver pour trouver une nouvelle Terre.'),
('Breaking Bad',     1,    'série', '2008-01-20', 'Walter White, prof de chimie atteint d un cancer, se lance dans la fabrication de méthamphétamine.'),
('Breaking Bad',     2,    'série', '2009-03-08', 'L empire de Heisenberg prend de l ampleur. Jesse et Walter s enfoncent dans la criminalité.'),
('The Matrix',       NULL, 'film',  '1999-03-31', 'Neo découvre que la réalité est une simulation et rejoint la résistance humaine contre les machines.'),
('Pulp Fiction',     NULL, 'film',  '1994-10-14', 'Histoires entrelacées de criminels, gangsters et d une danseuse à Los Angeles.'),
('Le Parrain',       1,    'film',  '1972-03-14', 'Vito Corleone dirige sa famille mafieuse. Son fils Michael va être entraîné dans l ombre du crime.'),
('Black Swan',       NULL, 'film',  '2010-12-03', 'Une danseuse obsédée par la perfection sombre dans la paranoïa en préparant le Lac des Cygnes.');
-- oeuvre_id attendus : 7=Dark Knight, 8=Interstellar, 9=BB S1, 10=BB S2,
--                      11=Matrix, 12=Pulp Fiction, 13=Le Parrain, 14=Black Swan


-- ------------------------------------------------------------------
-- GENRES DES NOUVELLES ŒUVRES
-- ------------------------------------------------------------------
INSERT INTO appartient VALUES
(7,  'Action'),
(7,  'Crime'),
(8,  'Science-Fiction'),
(8,  'Drame'),
(9,  'Crime'),
(9,  'Drame'),
(10, 'Crime'),
(10, 'Drame'),
(11, 'Science-Fiction'),
(11, 'Action'),
(12, 'Crime'),
(12, 'Drame'),
(13, 'Crime'),
(13, 'Drame'),
(14, 'Drame'),
(14, 'Thriller')
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------
-- PERSONNAGES (IDs auto : 7 → 13)
-- ------------------------------------------------------------------
INSERT INTO personnage (libelle) VALUES
('Bruce Wayne'),    -- 7
('Walter White'),   -- 8
('Jesse Pinkman'),  -- 9
('Neo'),            -- 10
('Jules Winnfield'),-- 11
('Vito Corleone'),  -- 12
('Nina Sayers');    -- 13


-- ------------------------------------------------------------------
-- RÉALISATEURS ↔ ŒUVRES
-- ------------------------------------------------------------------
INSERT INTO realise VALUES
(6, 1),    -- Nolan → Inception
(6, 7),    -- Nolan → The Dark Knight
(6, 8),    -- Nolan → Interstellar
(12, 12),  -- Tarantino → Pulp Fiction
(13, 13)   -- Coppola → Le Parrain
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------
-- RÔLES DES ACTEURS
-- ------------------------------------------------------------------
INSERT INTO joue VALUES
(7,  7,  7),   -- Bale      → Dark Knight   → Bruce Wayne
(8,  9,  8),   -- Cranston  → BB S1         → Walter White
(8,  10, 8),   -- Cranston  → BB S2         → Walter White
(9,  9,  9),   -- Paul      → BB S1         → Jesse Pinkman
(9,  10, 9),   -- Paul      → BB S2         → Jesse Pinkman
(10, 11, 10),  -- Reeves    → The Matrix    → Neo
(11, 12, 11),  -- Jackson   → Pulp Fiction  → Jules Winnfield
(14, 13, 12),  -- Brando    → Le Parrain    → Vito Corleone
(2,  14, 13)   -- Portman   → Black Swan    → Nina Sayers
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------
-- LIENS ENTRE ŒUVRES
-- ------------------------------------------------------------------
INSERT INTO lien VALUES
(2,  3,  'suite'),              -- Star Wars IV → V
(3,  4,  'suite'),              -- Star Wars V  → VI
(5,  6,  'suite'),              -- GoT S1       → S2
(9,  10, 'suite'),              -- Breaking Bad S1 → S2
(7,  1,  'même réalisateur'),   -- Dark Knight → Inception  (Nolan)
(7,  8,  'même réalisateur'),   -- Dark Knight → Interstellar (Nolan)
(1,  7,  'même réalisateur'),   -- Inception → Dark Knight
(1,  8,  'même réalisateur')    -- Inception → Interstellar
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------
-- PHOTOS — mise à jour des chemins existants + ajout nouveaux
-- (utilise placehold.co, compatible avec le thème sombre de l app)
-- ------------------------------------------------------------------
UPDATE photo SET chemin = 'https://placehold.co/300x450/0f172a/facc15?text=Inception'       WHERE id_oeuvre = 1;
UPDATE photo SET chemin = 'https://placehold.co/300x450/0f172a/facc15?text=Star+Wars+IV'    WHERE id_oeuvre = 2;
UPDATE photo SET chemin = 'https://placehold.co/300x450/0f172a/facc15?text=Game+of+Thrones' WHERE id_oeuvre = 5;

INSERT INTO photo (chemin, description_, id_utilisateur, id_oeuvre) VALUES
('https://placehold.co/300x450/0f172a/facc15?text=The+Dark+Knight', 'Affiche officielle',   1, 7),
('https://placehold.co/300x450/0f172a/facc15?text=Interstellar',    'Affiche officielle',   1, 8),
('https://placehold.co/300x450/0f172a/facc15?text=Breaking+Bad+S1', 'Affiche saison 1',     1, 9),
('https://placehold.co/300x450/0f172a/facc15?text=Breaking+Bad+S2', 'Affiche saison 2',     1, 10),
('https://placehold.co/300x450/0f172a/facc15?text=The+Matrix',      'Affiche officielle',   1, 11),
('https://placehold.co/300x450/0f172a/facc15?text=Pulp+Fiction',    'Affiche officielle',   1, 12),
('https://placehold.co/300x450/0f172a/facc15?text=Le+Parrain',      'Affiche officielle',   1, 13),
('https://placehold.co/300x450/0f172a/facc15?text=Black+Swan',      'Affiche officielle',   1, 14);


-- ------------------------------------------------------------------
-- COMMENTAIRES RÉALISTES
-- ------------------------------------------------------------------
INSERT INTO commentaire (contenu, date_commentaire, id_utilisateur, id_oeuvre) VALUES
('Le Joker de Heath Ledger est une performance inoubliable.',              '2024-02-01', 1, 7),
('Gotham n a jamais été aussi sombre et crédible. Chef-d oeuvre.',         '2024-02-03', 3, 7),
('La scène finale dans l espace est époustouflante.',                      '2024-02-10', 2, 8),
('Très dense scientifiquement, mais magistralement mis en scène.',         '2024-02-12', 5, 8),
('Bryan Cranston livre la performance de sa carrière.',                    '2024-03-01', 4, 9),
('L évolution de Walter White est terrifiante à regarder.',               '2024-03-05', 1, 10),
('Jesse Pinkman est le cœur émotionnel de la série.',                     '2024-03-08', 2, 10),
('Concept de simulation brillant, visuels d époque encore impressionnants.','2024-03-15', 3, 11),
('La scène red pill / blue pill reste culte 25 ans après.',               '2024-03-16', 5, 11),
('Dialogue anthologique : "Royale avec fromage".',                        '2024-04-01', 1, 12),
('Structure narrative non-linéaire parfaitement maîtrisée.',              '2024-04-03', 4, 12),
('Brando incarne un parrain immobile et terriblement puissant.',          '2024-04-10', 2, 13),
('Un film qui redéfinit le mot chef-d oeuvre.',                          '2024-04-12', 3, 13),
('Natalie Portman transcendante dans un rôle extrêmement exigeant.',      '2024-04-20', 1, 14);


-- ------------------------------------------------------------------
-- FAVORIS SUPPLÉMENTAIRES
-- ------------------------------------------------------------------
INSERT INTO favoris VALUES
(1, 7,  '2024-02-05'),
(2, 8,  '2024-02-15'),
(3, 12, '2024-04-05'),
(4, 9,  '2024-03-10'),
(5, 13, '2024-04-15'),
(1, 11, '2024-03-20'),
(2, 14, '2024-04-22')
ON CONFLICT DO NOTHING;
