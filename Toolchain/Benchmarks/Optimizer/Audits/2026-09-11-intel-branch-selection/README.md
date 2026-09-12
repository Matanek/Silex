# Comparaisons et branches sur Intel physique

Candidat : `1badca9d9c6b2a290db2242299faa9521c0ede5f`.
Référence Silex figée : `0b0374430f8c52bdaecf41d33439e7574d7f32d7`.
Campagne : https://github.com/Matanek/Silex/actions/runs/34643157776
Matrice native : https://github.com/Matanek/Silex/actions/runs/34643090825

## Changement et correction

Une comparaison utilisée uniquement par la branche immédiatement suivante
émet directement les branchements conditionnels X64. La sélection préserve
les largeurs signées et non signées, NaN, infinis et zéros signés ; elle refuse
les résultats partagés ou adressés et les entrées de contrôle indépendantes.
Le test négatif d'adresse a détecté une omission lors du développement :
la visite ordinaire des usages ne compte pas la formation d'une adresse.
La sélection contrôle donc explicitement cette exposition. La mutation qui
désactive la sélection fait échouer le test structurel positif.

Le parseur accepte aussi plusieurs `else if` successifs, correction séparée
au commit `756f7398259b5b84f7218560f3f830c8c6c2082b`.

Validation locale du candidat : 49/49 étapes, 2152/2152 tests internes et
183 tests de langage ; 50 régressions natives fixes, huit cas générés,
64 erreurs entières et 43 conversions sur ARM64 puis X64 sous Rosetta.
La robustesse qualifiée passe 144 paires, cinq triplets et 41 cas natifs.
La matrice distante valide macOS X64, Linux ARM64/X64 et Windows ARM64/X64,
avec le bootstrap Windows ARM64 intermédiaire. Linux et Windows exécutent
le témoin de comparaisons en Debug et Release. Le job Intel exécute le
corpus qualifié sur le même SHA que les mesures.

Une première qualification X64 lancée depuis le même répertoire que celle
d'ARM64 a rencontré un objet ARM64 dans ses sorties communes. Ce résultat est
exclu. La qualification X64 finale utilise la racine du groupe de Spec et
ses sorties distinctes ; les 526 objets natifs récents du portail ARM64 ont
été contrôlés comme ARM64. Rosetta ne constitue aucune preuve de vitesse Intel.

## Mesures appariées

Intel Core i7-8700B à 3,20 GHz, macOS 15.7.9, Apple Clang 17,
`translated=false`. Les deux compilateurs Silex utilisent le bootstrap
`ReleaseFast` avec `-Dcpu=baseline`. Six échauffements précèdent 21 rotations
des cinq configurations : Debug, Release, Clang historique `-O2`, Clang
`-O3` à champs de huit octets et ancien Release. Toutes les sorties sont
identiques. Les empreintes des sources et des cinq exécutables par charge,
les observations ordonnées et les binaires sont conservés.

| Charge | Avant, médiane ms | Après, médiane ms | Ratio apparié après/avant | Bornes à 96,08 % |
| --- | ---: | ---: | ---: | ---: |
| Arithmetic | 8,202 | 7,172 | 0,906703 | 0,885259–0,936078 |
| Objects | 26,460 | 25,960 | 0,955288 | 0,946340–1,001722 |
| Flocking | 2427,592 | 1935,725 | 0,788461 | 0,778594–0,808762 |

Les dispersions avant/après et les dérives entre moitiés respectent les seuils
inchangés de 20 % et 10 %. Les gains appariés sont établis pour Arithmetic
(9,33 %) et Flocking (21,15 %). Objects ne démontre pas de gain : sa borne
supérieure dépasse un.

## Parité encore absente

| Charge | Ratio Silex/Clang -O2 | Ratio Silex/Clang -O3, champs de huit octets |
| --- | ---: | ---: |
| Arithmetic | 1,243754 | 1,229804 |
| Objects | 4,622858 | 4,572064 |
| Flocking | 6,165608 | 4,006122 |

Tous les seuils de parité échouent. La référence `-O3` d'Objects échoue aussi
au seuil de dispersion (29,09 %). Le workflow est donc rouge malgré les
preuves de correction et les deux gains établis. Le nouveau comparateur ne
remplace pas l'ancien : chaque verdict reste visible et obligatoire.

La réduction statique de la boucle de rejet de Flocking (85 à 73 instructions,
33 à 29 accès pile, deux à zéro `SETcc`) explique le mécanisme, mais les gains
ci-dessus proviennent exclusivement de cette campagne physique appariée.
La Part 03 reste active ; ce résultat ne clôt ni Intel ni Physics ARM64.

Le manifeste scelle les fichiers de cet audit. L'ajout de ces preuves seul
ne modifie pas le candidat machine mesuré.
