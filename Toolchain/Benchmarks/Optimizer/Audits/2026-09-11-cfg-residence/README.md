# Résidence ARM64 et sorties de boucle

Le candidat `225ba12f8d8b4f2e434c0ae18bd0b6269c909373` améliore Objects et
Preparation sur ARM64 physique. La Part 03 reste active : la parité globale
avec Clang n'est pas atteinte.

## Mécanisme et validation

L'admission d'une région scalaire compte les opérations qui peuvent rejoindre
le retour de boucle. Une sortie froide placée entre l'en-tête et ce retour
n'est plus confondue avec le chemin répété. Les émetteurs incompatibles
conservent en pile leurs opérandes, résultats et valeurs réellement vivantes
avant/après selon le graphe de contrôle. Les adresses locales restent épinglées.

Le compilateur mesuré porte le SHA-256
`12284da5c06072a77ab69ee25cd523b91f820d7fc8a54dd88f2f6a7e926f05d1`.
La référence est `5ff94ab7471b4d2c2b1d3c7cbdb03b6572bbceae`. Les rapports
créés avant le commit identifient le candidat par cette empreinte ; ils
conservent leur libellé historique `uncommitted-compiler-sha256`.

Le portail final passe 49/49 étapes, 2157/2157 tests internes et 183 tests
de langage. L'oracle passe 27 cas sémantiques, 52 régressions natives fixes,
huit générées, 64 erreurs entières et 43 conversions sur ARM64, puis la
qualification X64 locale sous Rosetta. La robustesse qualifiée passe 144
paires, cinq triplets, 41 cas natifs, quatre négatifs et les stress cache/graphe.
Le nouveau témoin produit cinq lignes `true` en Debug/Release sur macOS ARM64
et X64 ; ses douze émissions couvrent les six cibles.

La [matrice native exacte](https://github.com/Matanek/Silex/actions/runs/34649947527)
est verte : macOS X64, Linux X64/ARM64, Windows X64/ARM64 et bootstrap Windows
ARM64. Les six journaux et les identifiants des jobs sont joints.
Le test structurel détecte la suppression de la correction : l'ancienne
allocation renvoie zéro résidence au lieu des dix attendues.

## Mesures ARM64 physiques

Hôte Apple M3 Pro, macOS 26.6.2, Darwin 25.6.0, sans traduction. Chaque
campagne utilise six échauffements et 21 rotations. Les rapports conservent
les échantillons, signatures, dispersions, dérives et intervalles appariés.

| Charge | Avant (ms) | Après (ms) | Après/avant | Après/Clang -O3 même layout |
|---|---:|---:|---:|---:|
| Objects | 10,161 | 8,538 | 0,849605 | 3,558800 |
| Flocking | 138,685 | 139,502 | 1,006500 | 0,837230 |
| Arithmetic | 2,154 | 2,234 | 1,025209 | 1,032527 |
| Preparation | 329,834 | 292,244 | 0,879391 | 1,238768 |
| Integration | 81,888 | 82,387 | 1,000530 | 1,600194 |

Objects gagne 15,04 % (intervalle 0,816884–0,885101) ; Preparation gagne
12,06 % (0,872629–0,895153). Flocking et Integration restent neutres.
Arithmetic est non concluant : la dispersion Clang -O3 atteint 23,75 %,
au-delà des 20 % admis. Les exécutables Arithmetic et Flocking sont identiques
à la référence ; les preuves binaires sont jointes. Flocking conserve sa
parité ; Objects et les deux charges Physics restent au-dessus du seuil.

Les sources Physics restent au commit `ab63f10d70e7afae2d3bfa5cff51e405c1197536`.
Les 32768 états de chaque charge sont identiques à la référence. Preparation
vérifie ses 26 champs (écart maximal 2,7e-7) ; Integration rejoue les
transitions (écart maximal 1,14e-5). Clang utilise -O3, -ffp-contract=fast et
SLOT8. Les binaires de comparaison et le banc sont joints.

Le chemin pair d'Objects passe de 65 à 43 instructions et de 25 à sept accès
pile ; le chemin impair passe de 40 à 18 instructions et de 18 à trois accès
pile. Un appel identique demeure à chaque itération. Les listes d'adresses
et désassemblages évitent de confondre taille totale et coût exécuté.

Les trois exécutables X64 sont strictement identiques à ceux de `5ff94ab`.
La campagne Intel physique de ce candidat reste donc la preuve temporelle
X64 applicable, avec ratios -O3 1,270308, 4,892208 et 3,911734. Il n'y a
pas de nouvelle mesure Intel revendiquée pour cette correction ARM64.

## Incidents et limites

Le premier portail a reçu SIGKILL sur le test Debug des positions entières.
Le binaire annoncé avait disparu lors de la collecte. L'extrait kernel
conserve le refus AppleSystemPolicy pour son chemin et son PID exacts ; les
messages AMFI génériques ne sont pas utilisés seuls comme diagnostic.
La correction Release n'est pas exécutée par ce test Debug. Le cas isolé
sans cache passe 2/2, puis le portail complet passe avec le même compilateur.
Aucun réglage de sécurité du système n'a été modifié.

La première mutation de test indexait le tableau vide de l'ancienne allocation
et déclenchait une assertion Zig. Une vérification explicite de longueur a
remplacé cet accès : le témoin positif passe et la mutation échoue désormais
normalement. Ce n'était pas un crash d'un programme natif produit par Silex.

Les invocations initiales rejetées de robustesse et de qualification X64
sont conservées avec leurs reprises valides depuis la racine du groupe.
Les seuils de performance n'ont pas été assouplis. Aucun résultat présent
n'autorise la clôture de la Part 03.

`manifest.json` scelle chaque fichier de cet audit hors manifest lui-même.
Les journaux bruts conservent leurs espaces d'origine.
