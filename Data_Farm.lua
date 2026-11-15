-- XbiGold : ce qui se farme et se vend bien sur WoW Forever (les noms viennent du jeu, en français)
-- Zones = identifiants de carte (uiMapID), traduits en jeu. Niveau = niveau conseillé de la zone.
local _, XG = ...

-- Zones (uiMapID)
local ELW, DUN, TEL, DUR, MUL, TIR = 1429, 1426, 1438, 1411, 1412, 1420
local WES, LOC, DAR, BAR, SIL, RED = 1436, 1432, 1439, 1413, 1421, 1433
local DUS, WET, ASH, STO, HIL, NEE = 1431, 1437, 1440, 1442, 1424, 1441
local ALT, ARA, DES, STV, DUW, BAD = 1416, 1417, 1443, 1434, 1445, 1418
local SWA, FER, HIN, SEA, TAN, AZS = 1435, 1444, 1425, 1427, 1446, 1447
local BLA, UNG, FEL, BUR, WPL, EPL = 1419, 1449, 1448, 1428, 1422, 1423
local WIN, SIT = 1452, 1451

-- cat : herb, ore, leather, cloth, elem, cook, fish, misc
XG.FARM = {
    -- Herbes : forte demande depuis que les potions de soins passent par les Premiers soins
    {id = 2447, cat = "herb", lv = {1, 15}, z = {ELW, DUR, MUL, TIR, TEL, DUN}, note = "Potions de soins (Premiers soins) + caisses du Marchand"},
    {id = 765, cat = "herb", lv = {1, 15}, z = {ELW, DUR, MUL, TIR, TEL}, note = "Caisses du Marchand (20)"},
    {id = 2449, cat = "herb", lv = {5, 20}, z = {ELW, DUR, MUL, TIR, WES, BAR}, note = "Prix en hausse depuis le lancement"},
    {id = 785, cat = "herb", lv = {10, 25}, z = {WES, DAR, BAR, SIL, LOC}, note = "Caisses du Marchand (10)"},
    {id = 2450, cat = "herb", lv = {10, 25}, z = {WES, DAR, BAR, SIL, RED}, note = "Potions de soins (Premiers soins)"},
    {id = 2453, cat = "herb", lv = {18, 30}, z = {RED, WET, ASH, STO, HIL}, note = "Potions de soins (Premiers soins)"},
    {id = 2452, cat = "herb", lv = {15, 30}, z = {WES, DAR, BAR, SIL, WET}, note = "Potions de vitesse, voleurs"},
    {id = 3355, cat = "herb", lv = {25, 40}, z = {ARA, STV, HIL, NEE}, note = "Alchimie et Premiers soins"},
    {id = 3356, cat = "herb", lv = {25, 40}, z = {ARA, HIL, STV, WET, DES}, note = "Caisses du Marchand (10)"},
    {id = 3357, cat = "herb", lv = {28, 40}, z = {ARA, STV, HIL, DES, SWA}, note = "Alchimie"},
    {id = 3369, cat = "herb", lv = {25, 40}, z = {DUS, DES, ARA}, note = "Cimetières : Bois de la Pénombre"},
    {id = 3818, cat = "herb", lv = {35, 45}, z = {STV, ARA, DUW, SWA, FER}, note = "Caisses du Marchand (10)"},
    {id = 3821, cat = "herb", lv = {35, 45}, z = {STV, ARA, DUW, SWA, FER, HIN}, note = "Caisses du Marchand (10)"},
    {id = 3358, cat = "herb", lv = {35, 45}, z = {ARA, DUW, SWA, FER, HIN}, note = "Alchimie"},
    {id = 3819, cat = "herb", lv = {35, 45}, z = {ALT}, note = "Une seule zone : souvent cher"},
    {id = 4625, cat = "herb", lv = {45, 55}, z = {SEA, BAD, TAN, BLA}, note = "Alchimie de haut niveau"},
    {id = 8831, cat = "herb", lv = {42, 55}, z = {TAN, FER, HIN, AZS, BAD}, note = "Alchimie"},
    {id = 8836, cat = "herb", lv = {45, 58}, z = {WPL, EPL, FEL}, note = "Alchimie"},
    {id = 8838, cat = "herb", lv = {45, 58}, z = {HIN, FER, UNG, AZS, FEL}, note = "Potions de soins supérieures (Premiers soins)"},
    {id = 8839, cat = "herb", lv = {45, 55}, z = {SWA, UNG}, note = "Alchimie"},
    {id = 8845, cat = "herb", lv = {45, 55}, z = {HIN}, note = "Grottes de Jintha'Alor, Maraudon : rare"},
    {id = 8846, cat = "herb", lv = {48, 58}, z = {FEL, BLA, DES, ASH}, note = "Alchimie"},
    {id = 13464, cat = "herb", lv = {50, 60}, z = {UNG, FEL, AZS, SIT, BUR}, note = "Potions de soins majeures (Premiers soins)"},
    {id = 13463, cat = "herb", lv = {50, 60}, z = {UNG, FEL, AZS, SIT, BUR}, note = "Caisses du Marchand (20), flacons"},
    {id = 13465, cat = "herb", lv = {52, 60}, z = {WIN, AZS, FEL, UNG, BUR}, note = "Flacons de raid"},
    {id = 13466, cat = "herb", lv = {53, 60}, z = {WPL, EPL, FEL}, note = "Flacons de raid"},
    {id = 13467, cat = "herb", lv = {55, 60}, z = {WIN}, note = "Flacons de raid"},
    {id = 13468, cat = "herb", lv = {55, 60}, z = {WIN, EPL, BUR, SIT}, note = "Prix plafonné à 50 po : un PNJ de Powderfuse Port le vend sans limite"},

    -- Minerais et barres
    {id = 2770, cat = "ore", lv = {1, 20}, z = {ELW, DUN, DUR, MUL, TIR, WES, LOC, BAR}, note = "En forte hausse depuis le lancement, caisses (20)"},
    {id = 2840, cat = "ore", lv = {1, 20}, z = {ELW, DUN, DUR, MUL, TIR, WES, LOC, BAR}, note = "Barres : +93 % la 1re semaine, caisses (20)"},
    {id = 2771, cat = "ore", lv = {10, 30}, z = {WES, RED, DUS, WET, ASH, STO, HIL, SIL}, note = "Caisses du Marchand (20)"},
    {id = 2775, cat = "ore", lv = {15, 35}, z = {RED, DUS, WET, ASH, STO, HIL}, note = "Rare : bijoux et ingénierie"},
    {id = 2772, cat = "ore", lv = {28, 45}, z = {ARA, DES, STV, BAD, NEE, ALT}, note = "Forge, ingénierie"},
    {id = 2776, cat = "ore", lv = {30, 45}, z = {ARA, DES, STV, BAD}, note = "Rare"},
    {id = 3858, cat = "ore", lv = {40, 55}, z = {HIN, BAD, SEA, TAN, FEL, AZS}, note = "Caisses du Marchand (20)"},
    {id = 7911, cat = "ore", lv = {40, 55}, z = {HIN, BAD, SEA, TAN, UNG}, note = "Rare : arcanite, forge"},
    {id = 10620, cat = "ore", lv = {50, 60}, z = {UNG, WIN, BUR, EPL, SIT}, note = "Caisses du Marchand (20)"},
    {id = 11370, cat = "ore", lv = {50, 60}, z = {BUR}, note = "Profondeurs de Blackrock uniquement"},

    -- Cuirs (le cuir a mieux tenu ses prix que le reste)
    {id = 2318, cat = "leather", lv = {1, 20}, z = {ELW, DUR, MUL, WES, BAR, DAR}, note = "Caisses du Marchand (20)"},
    {id = 2319, cat = "leather", lv = {18, 30}, z = {RED, WET, ASH, STO, HIL, BAR}, note = "Caisses du Marchand (20)"},
    {id = 4234, cat = "leather", lv = {28, 42}, z = {ARA, DES, STV, NEE, DUW}, note = "Caisses du Marchand (20)"},
    {id = 4304, cat = "leather", lv = {38, 50}, z = {FER, HIN, TAN, STV, SWA}, note = "Travail du cuir, quêtes"},
    {id = 8170, cat = "leather", lv = {48, 60}, z = {UNG, WIN, FEL, EPL, BUR}, note = "Quêtes et artisanat de haut niveau"},
    {id = 15417, cat = "leather", lv = {50, 56}, z = {UNG}, note = "Diablosaures d'Un'Goro : très recherché"},

    -- Tissus (tombent sur les humanoïdes)
    {id = 2589, cat = "cloth", lv = {5, 15}, z = {ELW, DUR, WES, BAR, DAR}, note = "Peu cher : vends au marchand tant que le dépôt min. est de 1 pa"},
    {id = 2592, cat = "cloth", lv = {15, 25}, z = {RED, WET, SIL, ASH, HIL}, note = "Caisses du Marchand (40)"},
    {id = 4306, cat = "cloth", lv = {25, 40}, z = {DUS, ARA, STV, DES, ALT}, note = "Caisses du Marchand (40)"},
    {id = 4338, cat = "cloth", lv = {35, 50}, z = {STV, DUW, BAD, FER, HIN, TAN}, note = "Caisses du Marchand (40)"},
    {id = 14047, cat = "cloth", lv = {48, 60}, z = {WPL, EPL, WIN, BUR, FEL}, note = "Caisses du Marchand (40)"},
    {id = 14256, cat = "cloth", lv = {50, 58}, z = {FEL}, note = "Satyres de Gangrebois"},

    -- Éléments
    {id = 7068, cat = "elem", lv = {38, 50}, z = {BAD, SEA, ARA}, note = "Élémentaires de feu"},
    {id = 7067, cat = "elem", lv = {35, 50}, z = {BAD, ARA, DES}, note = "Élémentaires de terre"},
    {id = 7070, cat = "elem", lv = {35, 50}, z = {DUW, ARA, SWA}, note = "Élémentaires d'eau"},
    {id = 7069, cat = "elem", lv = {38, 50}, z = {ARA, TAN, AZS}, note = "Élémentaires d'air"},
    {id = 7077, cat = "elem", lv = {48, 56}, z = {SEA, BUR}, note = "Élémentaires de feu"},
    {id = 7078, cat = "elem", lv = {50, 60}, z = {SEA, BUR}, note = "Élémentaires de feu"},
    {id = 7080, cat = "elem", lv = {50, 60}, z = {FEL, AZS, EPL}, note = "Élémentaires d'eau, quêtes de set"},
    {id = 7076, cat = "elem", lv = {50, 60}, z = {SIT, AZS, BUR}, note = "Élémentaires de terre"},
    {id = 7082, cat = "elem", lv = {50, 60}, z = {SIT, AZS, UNG}, note = "Élémentaires d'air"},
    {id = 12808, cat = "elem", lv = {55, 60}, z = {WPL, EPL}, note = "Fantômes des Maleterres"},

    -- Cuisine
    {id = 12207, cat = "cook", lv = {45, 55}, z = {HIN, WIN, FER}, note = "Chouettards : quête « Surprise de palourdes »"},
    {id = 12208, cat = "cook", lv = {50, 58}, z = {WIN, BUR}, note = "Loups : cuisine de haut niveau"},
    {id = 3712, cat = "cook", lv = {30, 45}, z = {WET, DUW, SWA}, note = "Tortues"},
    {id = 3730, cat = "cook", lv = {25, 40}, z = {HIL, ARA, ALT}, note = "Ours"},
    {id = 7974, cat = "cook", lv = {38, 50}, z = {STV, DUW, TAN}, note = "Palourdes de la côte"},
    {id = 12184, cat = "cook", lv = {48, 56}, z = {UNG}, note = "Raptors d'Un'Goro"},

    -- Pêche
    {id = 6522, cat = "fish", lv = {10, 25}, z = {BAR}, note = "Oasis des Tarides : poissons déviants"},
    {id = 6358, cat = "fish", lv = {15, 40}, z = {WES, BAR, WET, STV, DAR}, note = "Huile de bouche-noire (potions)"},
    {id = 6359, cat = "fish", lv = {25, 45}, z = {STV, DUW, WET}, note = "Huile de vivenageoire"},
    {id = 13422, cat = "fish", lv = {40, 60}, z = {STV, TAN, AZS, FER}, note = "Huile d'écaille-de-pierre (élixirs de défense)"},

    -- Divers
    {id = 4589, cat = "misc", lv = {40, 52}, z = {ALT, HIN, FER, AZS}, note = "Griffons/hippogriffes. Quête Horde (10) + Chapeau d'amiral (couture)"},
    {id = 4611, cat = "misc", lv = {30, 45}, z = {STV}, note = "Palourdes : quête « Pêche aux perles » (9)"},
    {id = 5500, cat = "misc", lv = {20, 30}, z = {WET}, note = "Palourdes de la côte : marché saturé"},
    {id = 10940, cat = "misc", lv = {5, 25}, z = {}, note = "Désenchantement. Caisses du Marchand (20)"},
    {id = 249427, cat = "leather", lv = {10, 26}, z = {BAR}, note = "Matériau RARE (Forever) : bonus de dépeçage"},
    {id = 249399, cat = "herb", lv = {10, 40}, z = {}, note = "Matériau RARE (Forever) : bonus d'herboristerie, teinture"},
    {id = 249391, cat = "ore", lv = {10, 40}, z = {}, note = "Matériau RARE (Forever) : bonus de minage, acide"},
}

XG.FARM_CATS = {
    {value = "all", label = "Tout", w = 56},
    {value = "quest", label = "Quêtes", w = 64},
    {value = "herb", label = "Herbes", w = 64},
    {value = "ore", label = "Minerais", w = 70},
    {value = "leather", label = "Cuirs", w = 56},
    {value = "cloth", label = "Tissus", w = 58},
    {value = "elem", label = "Éléments", w = 70},
    {value = "other", label = "Autres", w = 60},
}
XG.CAT_LABEL = {herb = "Herbe", ore = "Minerai", leather = "Cuir", cloth = "Tissu", elem = "Élément",
                cook = "Cuisine", fish = "Pêche", misc = "Divers", quest = "Quête"}

-- Recettes vendues en stock limité par des PNJ, revendables à l'HV (f : 1 Alliance, 2 Horde, 0 les deux)
XG.LIMITED_RECIPES = {
    {id = 18949, npc = "Saenorion", z = 1457, f = 1, note = "Brassards barbares : ~20 pa chez le PNJ, vendu bien plus cher"},
    {id = 18949, npc = "Joseph Moore", z = 1458, f = 2, note = "Brassards barbares"},
    {id = 5642, npc = "Ulthir", z = 1457, f = 1},
    {id = 5642, npc = "Soolie Berryfizz", z = 1455, f = 1},
    {id = 5642, npc = "Kor'geld", z = 1454, f = 2},
    {id = 5642, npc = "Vendor-Tron 1000", z = 1443, f = 0},
    {id = 5643, npc = "Ulthir", z = 1457, f = 1, note = "Stock de 2"},
    {id = 5643, npc = "Hagrus", z = 1454, f = 2, note = "Stock de 2"},
    {id = 5643, npc = "Vendor-Tron 1000", z = 1443, f = 0},
    {id = 13477, npc = "Ulthir", z = 1457, f = 1, note = "Stock de 1"},
    {id = 13477, npc = "Algernon", z = 1458, f = 2, note = "Stock de 1"},
    {id = 13478, npc = "Soolie Berryfizz", z = 1455, f = 1, note = "Stock de 1"},
    {id = 13478, npc = "Kor'geld", z = 1454, f = 2, note = "Stock de 1"},
    {id = 10318, npc = "Cowardly Crosby", z = 1434, f = 0, note = "Chapeau d'amiral : utilise les longues plumes élégantes"},
    {id = 14468, npc = "Qia", z = 1452, f = 0, note = "Sac en étoffe runique"},
    {id = 4355, npc = "Micha Yance", z = 1424, f = 1},
    {id = 4355, npc = "Ghok'kah", z = 1445, f = 2},
    {id = 10311, npc = "Elynna", z = 1457, f = 1},
    {id = 10311, npc = "Mahu", z = 1456, f = 2},
    {id = 14635, npc = "Rikqiz", z = 1434, f = 0},
    {id = 18239, npc = "Rikqiz", z = 1434, f = 0},
    {id = 13311, npc = "Gnaz Blunderflame", z = 1434, f = 0, note = "Dragonnet mécanique"},
    {id = 10609, npc = "Ruppo Zipcoil", z = 1425, f = 0, note = "Dragonnet mécanique en mithril"},
    {id = 18649, npc = "Darian Singh", z = 1453, f = 1},
    {id = 18647, npc = "Sovik", z = 1454, f = 2},
    {id = 16041, npc = "Gearcutter Cogspinner", z = 1455, f = 1},
    {id = 16041, npc = "Sovik", z = 1454, f = 2},
    {id = 16042, npc = "Gearcutter Cogspinner", z = 1455, f = 1},
    {id = 16042, npc = "Sovik", z = 1454, f = 2},
    {id = 18652, npc = "Xizzer Fizzbolt", z = 1452, f = 0},
    {id = 18656, npc = "Xizzer Fizzbolt", z = 1452, f = 0},
    {id = 15726, npc = "Masat T'andr", z = 1435, f = 0},
    {id = 15735, npc = "Nioma", z = 1425, f = 0},
    {id = 15741, npc = "Leonard Porter / Werg Thickblade", z = 1422, f = 0},
    {id = 15751, npc = "Blimo Gadgetspring", z = 1447, f = 0},
    {id = 15758, npc = "Nergal", z = 1449, f = 0},
}

-- Conseils affichés sur l'accueil (issus des retours de la communauté Forever)
XG.TIPS = {
    "Les objets à moins de ~1 pa se vendent mieux au marchand tant que le dépôt minimum de l'HV est de 1 pa par annonce.",
    "À prix égal, c'est l'annonce la plus récente qui part en premier : inutile de casser le prix de 1 pc, aligne-toi.",
    "Les herbes de bas niveau (Pacifique, Églantine, Doulourante...) servent maintenant aux potions de soins des Premiers soins.",
    "Les caisses du Marchand (Durotar / Les Trois Chemins) absorbent beaucoup de matériaux : tissus, minerais, herbes, cuir.",
    "Le butin de vente arrive par courrier environ 1 h après la vente.",
    "Les HV neutres (Gadgetzan, Baie-du-Butin, Long-guet) prennent 15 % au lieu de 5 % : à réserver aux objets très demandés par l'autre faction.",
    "Les matériaux de niveau 30-45 ont beaucoup baissé : vends vite ce que tu farmes dans ces zones.",
    "Avant l'ouverture des raids (9 décembre), les flacons, élixirs et la nourriture vont monter.",
    "Les bots achètent les annonces trop basses en quelques secondes : achète les vraies erreurs de prix vite.",
}
