# Fermeture tardive des feuilles scalaires

Implémentation : `f4a9067`. Le nettoyage mémoire et SSA peut transformer un
helper qui allouait une liste en deux additions scalaires, après le premier
inlining. Sa boucle appelante continuait d'appeler cette feuille et de sauvegarder
ses valeurs autour de l'appel.

Le pipeline réexamine une seule fois les feuilles à un bloc et valeurs scalaires,
sous les règles de coût existantes. Seuls paramètres et opérandes/résultats vivants
contraignent ce domaine : les anciens types de descripteurs inutilisés ne décrivent
plus une opération sur collection. Agrégats utilisés, références, appels et effets
restent exclus de cette reprise. Sans appel éligible, le programme est retourné
immédiatement ; sinon plages et faits SSA sont recalculés après clonage.
Désactiver `value_inlining` désactive aussi la reprise. L'arrêt après simplification
SSA observe l'état précédant cette reprise.

Les tests montrent un appel avant, aucun après, et un appel conservé avec inlining
désactivé. Ils protègent le débordement de l'initialiseur inutilisé et l'affichage
ordonné d'un helper à effets. La régression source exécute 5 000 itérations.
Les premières attentes non satisfaites sont conservées : le rejet portait sur
un descripteur devenu inutilisé ; le filtre a été corrigé sur les valeurs vivantes.
Les contrôles n'ont pas été affaiblis.

## Mesure ARM64

Apple M3 Pro, macOS ARM64 Release, 30 millions d'itérations, processus complet
avec démarrage. Six rotations d'échauffement, puis 21 rotations mesurées avec
ordre alterné et sortie exacte `894` contrôlée.

| Configuration | Médiane | MAD |
| --- | ---: | ---: |
| Compilateur parent, helper naturel | 150.146209 ms | 3.015791 ms |
| Compilateur parent, contrôle direct | 61.379042 ms | 0.120000 ms |
| Candidat, source naturelle inchangée | 61.366333 ms | 0.103917 ms |

Ratio apparié candidat/parent : 0.409113, MAD 0.007797 ; candidat/direct :
1.000542, MAD 0.001667. La réduction gagne environ 59 % ; ce n'est pas une
mesure de parité Clang, de consommateur complet ou de CPU X64 physique.
Le compilateur parent retrouvé dans le cache est identifié par SHA-256 ; les
deux contrôles recompilés reproduisent leurs binaires initiaux octet pour octet.
Les JSON scellent commandes, sources, exécutables et observations individuelles.

Dans la boucle ARM64, un appel, sept chargements et sept stockages disparaissent.
Le segment passe de 41 à 11 instructions (10 pour le contrôle direct). La frame
passe de 96 à 112 octets, sans trafic supplémentaire dans la boucle. Les anciennes
fonctions inaccessibles encore présentes ne sont pas du travail exécuté.

## Validation cumulative

`zig build check test optimizer-gate optimizer-robustness-qualified install` :
53 étapes et 2 139 tests verts ; 183 tests du langage, 26 cas de corpus,
47 régressions natives fixes et huit générées, 128 différentiels internes et
32 LLVM. Robustesse : 144 paires, cinq triplets, 41 cas natifs, quatre négatifs,
puis stress de cache et packages. Les messages `known-gap` et de famille LLVM
manquante viennent des tests négatifs attendus ; le résumé global est vert.

Préparation complète, modules et feuille tardive sont requalifiés sur le même
compilateur : 36 émissions, dont 12 exécutions macOS Debug/Release ARM64 et X64
Rosetta ; 12 exécutions LLVM brut/Release à O0/O3 concordantes. Linux et Windows
restent des émissions. Aucun seuil, budget protégé ou coût d'inlining n'est modifié.
Le défaut de débordement X64 antérieur reste attribué au travail machine.

`portable-family-review.md` relie les résultats aux familles et conserve les
limites : ABI/copies/résidence, qualifications physiques, consommateurs et
admission distante ne deviennent pas verts ici. Le contrôle de préparation aplatie
rejeté et les mesures inconclusives de dominance restent dans l'audit précédent.
Aucun consommateur n'a été réécrit. Les fichiers bruts gardent leurs octets.
