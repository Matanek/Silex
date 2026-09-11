# Retours exclusifs et résidences flottantes X64

Le candidat `7bd153ce94975ccc2143679a85ef99fd1fa0db4f` traite les retours
terminaux comme des lectures de leurs seuls spans retournés. Leur sortie du
graphe de contrôle ne peut invalider les valeurs utilisées exclusivement par
une autre branche. Les appels conservent la barrière complète.

Compilateur local SHA-256 :
`632198aa55b946e08b7bf5e9ce6ffbc03dd50a8d2a44f38dbe771b2275c2b743`.
Le checkpoint précédent est `6530e140752f3d93f2f1226926be254c04e90760` ;
la référence de mesure cumulée est `225ba12f8d8b4f2e434c0ae18bd0b6269c909373`.

Les six tests ciblés passent. La mutation qui retire seulement la nouvelle
classification des retours échoue sur le témoin dédié, sans crash.
Le portail passe 49/49 étapes, 2159 tests internes et 183 tests langage.
L’oracle passe 31/31 étapes, 74 tests, 53 cas natifs fixes, huit générés,
64 erreurs entières et 43 conversions. La qualification X64 sous Rosetta
passe aussi ces 53/8/64/43 cas. La robustesse passe 144 paires, cinq triplets,
41 natifs, quatre négatifs et les stress du cache et du graphe.
Le témoin élargi donne dix lignes `true` en Debug/Release sur macOS ARM64
et X64. Douze émissions couvrent les six cibles.

Les trois exécutables ARM64 sont identiques à `225ba12`, ainsi qu’Arithmetic
et Objects X64. Le comptage statique de `steer` passe de 437 à 425 instructions
et de 176 à 166 accès pile. Il ne suffit pas à établir un gain temporel.
Les exécutables et désassemblages exacts sont conservés.

La [matrice native](https://github.com/Matanek/Silex/actions/runs/34652524590)
est verte sur les six jobs : macOS X64, Linux X64/ARM64, Windows X64/ARM64
et bootstrap Windows ARM64. Leurs journaux et identifiants sont joints.
La [campagne Intel appariée](https://github.com/Matanek/Silex/actions/runs/34652525960)
reste en cours. Aucun gain Intel physique n’est encore revendiqué ici et
la Part 03 reste active.

`manifest.json` scelle les fichiers de cette preuve, hors manifest lui-même.
