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
