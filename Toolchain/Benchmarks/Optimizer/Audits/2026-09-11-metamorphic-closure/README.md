# Fermeture exécutable des variantes métamorphiques

Le rapport antérieur comptait tous les corps conservés dans l'IR portable.
Après inlining, cette table contient aussi les helpers devenus inaccessibles,
alors que le natif et LLVM les éliminent de la fermeture exécutée.

La sonde avant correction applique le calcul de fermeture existant aux mêmes
sources et au même optimiseur : les formes directe/helper passent de 2/5 à
2/2 instructions, et les helpers imbriqués de 19/23 à 15/15. Les blocs et
appels concordent également. Les nombres bruts ne représentaient donc pas du
travail supplémentaire exécuté. Aucun changement d'inlining n'est justifié
par ces deux écarts.

Le rapport utilise désormais `profileReachable`, comme la comparaison LLVM.
Un test protège les cinq paires du corpus et leurs classes de qualité, avec
égalité des observables. Les cinq paires sont aussi exécutées en natif
Debug/Release par la campagne cumulative. Les bibliothèques sans `main`
conservent tous leurs corps ; le contrat de fermeture existant couvre appels,
références de fonctions, cibles dynamiques et finalizers. Ses tests restent verts.

Le TSV initial reste conservé ; le rapport nouveau ne modifie ni les sources
comparées, ni les seuils, ni les transformations du compilateur. La classification
« équivalente » est une preuve de structure finie, pas une mesure temporelle.

Le manifeste scelle le parent et les sources exactes de la correction, les
rapports, la sonde et les portails cumulatifs. Les logs gardent leurs octets
originaux, y compris les diagnostics attendus des tests négatifs.
