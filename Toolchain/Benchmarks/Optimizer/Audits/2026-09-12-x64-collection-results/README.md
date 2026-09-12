# Résultats flottants des lectures de collection X64

Candidat `3e584015c9dc3a1cbfa687c7e36ba6bf75eab28d`, baseline code `6b3f302`.
Les feuilles flottantes vivantes des lectures fixes, dynamiques et de vues
peuvent occuper une couleur laissée libre par l’allocation scalaire précédente.
Les entrées, valeurs adressées et feuilles mortes restent en pile. Les couleurs
préexistantes ne sont jamais déplacées. Les transferts conservent les 64 bits
du slot et les contrôles d’index, y compris l’index négatif.

Les contre-preuves échouent avec le stockage antérieur et lorsque la protection
des feuilles mortes est retirée. Le test inclut copies, alias d’adresse,
redéfinition ultérieure d’un slot et vraie barrière d’appel. La fixture native
vérifie treize assertions, dont float32, float64, NaN et zéro signé chargé.
Douze émissions, quatre exécutions macOS ARM64/X64 en Debug/Release passent.
Le portail complet passe 49/49 étapes, 2163 tests internes et 183 tests de
langage. L’oracle passe 31/31 étapes, 74 tests, 56 régressions fixes, huit
scénarios, 64 erreurs entières et 43 conversions sur ARM64 physique ; les
mêmes qualifications natives passent sous Rosetta X64. La robustesse couvre
144 paires, cinq triplets, 41 natifs, quatre négatifs et les stress cache/graphe.
Le YAML et les quinze corps Bash passent ; les attentes PowerShell sont relues.

Une allocation conjointe initiale augmentait le trafic mémoire de Flocking ;
elle est conservée exactement hors produit dans EagerCollectionResults sous
le répertoire de preuves temporaire. La variante finale réduit les comptes
statiques complets de Flocking.steer de 355 à 354 instructions et de 166 à
163 accès pile ; une autre fonction passe de 179 à 177 accès. Ces comptes
incluent les chemins froids et ne constituent pas une mesure de gain.
Arithmetic et Objects restent binaires identiques à 6b3f302, comme les trois
charges ARM64. Le changement de code est limité au chemin X64 : la fonction
partagée allocateFloatScalarsFor n’a aucun appelant produit ARM64.

Le build final conserve les six binaires de benchmark et dix des douze
fixtures exactement. Les deux PE ARM64 ne diffèrent que par les horodatages
COFF et debug, dont les offsets sont résolus par les en-têtes ; aucun champ
machine n’est exclu arbitrairement. Le compilateur final est identifié dans
le manifeste. Les binaires locaux servent à la correction, jamais à une
revendication de performance Intel sous Rosetta.

La campagne Intel doit comparer à 737fc8c : Arithmetic est inchangé, Objects
requalifie l’extension scalaire de classe (sa première référence était trop
dispersée) et Flocking mesure les résultats chargés, son code étant identique
entre 737fc8c et 6b3f302. Les seuils et vingt-et-une rotations après six
échauffements restent inchangés. Les campagnes distantes sont en cours ;
aucune parité physique ni aucun gain de ce candidat n’est encore acquis.

Les exécutions distantes X64 sont vertes sur le SHA exact 3e58401 : macOS
34659581895 (job 103459098981), Linux 34659583268 (103459103243), Windows
34659584418 (103459106064). Elles comprennent la fixture à treize assertions
en Debug/Release. Les journaux sont le texte décodé du connecteur, avec
fins de ligne LF. Le run de mesure Intel 34659585652 reste en cours.

## Qualification Intel achevée

Run `34659585652`, Intel i7-8700B physique, macOS 15.7.9, Clang 17,
21 rotations après six échauffements. Les 56 régressions fixes, huit scénarios,
64 erreurs entières et 43 conversions passent. Les quinze exécutables sont
vérifiés par SHA-256 ; l'archive GitHub `10287013877` porte l'empreinte
`6bdc4e52db0bbb4ab934c9886b8e7516c6cec4b264497bd847f02bf16574c398`.

Toutes les paires candidat/baseline sont stables. Arithmetic est neutre :
8.664615 → 8.731499 ms, ratio apparié 1.032835 (0.996886..1.049795).
Objects gagne 15,70 % : 21.663621 → 18.119257 ms, ratio 0.842993
(0.814624..0.849505). Son code est identique à 6b3f302 : cette campagne
qualifie donc l'inlining des feuilles de classe auparavant non concluant.
Flocking gagne 2,46 % : 1780.282131 → 1733.043817 ms, ratio 0.975430
(0.948946..0.994844), attribuable aux résultats chargés en registres.
Les ratios contre Clang -O3 à layout équivalent restent respectivement
1.297466, 3.160441 et 3.008673 ; la parité demeure rouge.
