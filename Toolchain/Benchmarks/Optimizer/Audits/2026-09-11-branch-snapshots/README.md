# Lectures scalaires dans les branches exclusives

Le candidat `5ff94ab7471b4d2c2b1d3c7cbdb03b6572bbceae` réduit le temps de
Preparation sur ARM64 physique de 16,7 %. La Part 03 reste ouverte : les
seuils de parité ne sont pas tous satisfaits.

## Mécanisme et correction

`branch_snapshot_sinking` clone un suffixe de lectures scalaires au début des
deux successeurs exclusifs d'une branche, avec des identifiants distincts.
Le contrôle de bornes reste avant la branche. Les lectures gardent leur ordre
et précèdent les effets de chaque chemin. Une entrée partagée, un usage dans
la condition ou après la jonction, plusieurs définitions ou un effet interposé
refusent la transformation. Les onze fonctions d'opérandes ont été extraites
sans changement de corps ; leur comparaison est jointe.

Compilateur local SHA-256 :
`c157bb3bcd51eeb4db4edbca79623613b9860d679f6a211705fb8b726461b72c`.
Référence : `1badca9d9c6b2a290db2242299faa9521c0ede5f`.

Le portail final passe 49/49 étapes, 2155/2155 tests internes et 183 tests de
langage. L'oracle passe 51 régressions fixes, huit cas générés, 64 erreurs
entières et 43 conversions, sur ARM64 et sur X64 local sous Rosetta.
La robustesse qualifiée passe 144 paires, cinq triplets, 41 cas natifs et
quatre négatifs, puis les stress du cache et du graphe. Douze émissions et
quatre exécutions du témoin couvrent les deux modes et les six cibles.

La [matrice native](https://github.com/Matanek/Silex/actions/runs/34646654100)
est verte sur le SHA exact : macOS X64, Linux X64/ARM64, Windows X64/ARM64,
avec bootstrap Windows ARM64 distinct. Les journaux et identifiants des six
jobs réussis sont conservés. La mesure ARM64 locale emploie un Apple M3 Pro
physique, macOS 26.6.2, Darwin 25.6.0, sans traduction.

## Mesures ARM64

Les sources Physics canoniques sont inchangées, au commit de package
`ab63f10d70e7afae2d3bfa5cff51e405c1197536`. Clang emploie `-O3`,
`-ffp-contract=fast` et `-DSLOT8`. Chaque campagne utilise six échauffements
et 21 rotations ; dispersion et dérive respectent leurs seuils.

| Charge | Avant (ms) | Après (ms) | Clang même layout (ms) | Après/avant apparié | Après/Clang apparié |
|---|---:|---:|---:|---:|---:|
| Preparation | 386,501 | 321,403 | 216,631 | 0,833444 | 1,478405 |
| Integration | 80,775 | 80,666 | 50,371 | 0,995747 | 1,584450 |

Preparation : intervalle après/avant 0,824784–0,846990 à 96,08 % ; gain
établi. Integration : intervalle 0,979986–1,006071 ; aucun gain établi.
Les 32768 états avant/après sont exactement identiques pour chaque charge.
Preparation vérifie les 26 champs ; Integration rejoue chaque transition.
Les signatures temporelles sont vérifiées selon le contrat de chaque oracle.

Le chemin de signature effectivement exécuté passe de 183 à 139 instructions
et de 90 à 46 accès pile. La fonction entière passe de 2943 à 2977
instructions : sa taille totale ne représente pas le coût du chemin chaud.
Les plages d'adresses et désassemblages sont joints.

La campagne générale ARM64 passe la parité d'Arithmetic et Flocking avec les
deux références Clang. Face à `-O3` au même layout, les ratios appariés sont
0,978110, 4,541377 et 0,849964 pour Arithmetic, Objects et Flocking.
Objects reste rouge. Arithmetic et Objects ne montrent pas de changement
établi par rapport à la référence ; Flocking montre une petite hausse de
0,68 % (intervalle 1,001544–1,012226), tout en conservant sa parité.

## Incidents conservés

Un premier portail a reçu SIGKILL sur un test natif d'ownership. Le binaire
annoncé avait disparu lors de sa collecte ; la cause demeure inconnue.
Le test utilise Debug, qui n'exécute pas le nouveau passage Release. Le cas
isolé sans cache passe 3/3, puis le portail complet passe sans changement du
compilateur. Le premier journal et la tentative rejetée de `test --debug`
sont conservés.

Le tableau de robustesse scellé de l'ancienne liste de 13 passes refusait son
remplacement par les 14 passes actuelles. L'ancien tableau est préservé sous
son empreinte avant génération du nouveau résultat. Il n'a pas été effacé.

Le premier échauffement Integration utilisait à tort la signature de la
trajectoire Clang pour Silex. Il a été rejeté avant les échantillons. Le banc
corrigé suit le contrat existant : signature propre de chaque trajectoire
entièrement vérifiée et rejouée. Les tolérances n'ont pas changé.

## Limites

La [campagne Intel appariée](https://github.com/Matanek/Silex/actions/runs/34646656058)
sur ce candidat est distincte de la matrice de correction. Ses résultats
doivent être scellés après son achèvement. Rosetta ne constitue jamais une
mesure de performance Intel physique. Aucun résultat présent n'autorise la
clôture de la Part 03.

`manifest.json` donne les empreintes des fichiers de cette preuve, hors
manifest lui-même. Les journaux bruts conservent leurs espaces d'origine.
