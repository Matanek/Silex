# Cache scalaire des champs privés

Résultat retenu : correction `72b81abeba28bbf2a6dd46437f2cb1da3671e19e`,
cache actif pour ARM64, représentation précédente pour X64. Le gain mesuré
sur Objects ARM64 est conservé par identité binaire. L'essai universel
`b3273cc` a révélé un ralentissement Intel et n'est pas le candidat final.

Candidat `b3273cc40505d50b94c3c03a82ef6abb6bbc12be`, baseline Silex
`b8d01d73233a88a080170b53096f2a72bbd8d98e`. La référence Silex pilote
le progrès ; les contrats sémantiques et la parité Clang restent distincts.

Une classe scalaire créée en entrée, dont toutes les utilisations restent
privées, transmet ses champs lus par des locaux puis par la passe SSA.
Le compilateur conserve l'allocation et ses erreurs, les écritures dans
l'objet, les références et la destruction. Copies et alias locaux partagent
le même état. Échappement, adresse, héritage, ressource, instance mélangée,
identité réutilisée et lecture après destruction refusent cette preuve.
Dans Objects.calculate, trois lectures du Counter disparaissent, tandis que
son allocation, deux sites d'écriture, son retain et son drop restent présents.
Le champ du Snapshot final demeure une lecture de structure distincte.

Le témoin source à écritures conservées isole ce mécanisme : 11.61 % de gain
diagnostique. Avec le benchmark Objects original et le compilateur modifié,
Apple M3 Pro physique, ARM64, Darwin 25.6.0, Release : médianes par lancement
9.063820 → 8.256412 ms ; ratio apparié 0.909284, intervalle sur la médiane
0.905398..0.912194. Les critères de stabilité passent, soit 9.07 % de gain
qualifié face à Silex figé. Vingt et une observations, six échauffements,
seize lancements par configuration et observation, ordre ABBA/BAAB équilibré.
Les sorties sont exactement 6000000. Ce résultat ne prouve aucune parité Clang.

Les binaires Arithmetic et Flocking restent identiques sur macOS ARM64 et
X64 ; les sections __text des noyaux Physics contrôlés restent identiques.
Sur Objects, onze compilations hors cache après deux échauffements par cible
ne montrent pas de hausse de temps CPU médian ; RSS médiane +114688 octets,
tailles inchangées (32952 ARM64, 28856 X64). Ces coûts très courts restent
un diagnostic local, pas une qualification de performance de compilation.

Validation locale : 47/47 étapes check/test/optimizer-gate, 1994 tests internes,
184 tests de langage ; 57 régressions fixes, huit scénarios, 64 erreurs et
43 conversions en ARM64 puis X64. Robustesse : 144 paires, cinq triplets,
41 cas natifs, quatre négatifs et stress cache/graphe. Quatre tests ciblés et
deux contre-preuves détectent la suppression du mécanisme ou de la barrière
d'adresse. Douze émissions et quatre exécutions macOS de la fixture à dix-huit
true passent. YAML et dix-sept corps Bash sont vérifiés ; les scripts Windows
passent également leur exécution native distante.

Les deux premiers portails conservés ont échoué avant qualification : des
copies .sx dans l'ancien audit étaient découvertes comme modules. La correction
3bbe24c les conserve en .sx.txt, octets inchangés, manifeste actualisé. Une
première commande de robustesse a rencontré le refus du cache Zig isolé ;
la relance depuis le groupe avec accès natif a passé. Ces essais ne sont pas
présentés comme des validations vertes. La sonde hot-budget produit ses trois
artefacts puis termine par HotFunctionNotRegistered : inspection structurelle
seulement, car le témoin indépendant n'est pas une fonction chaude du registre.

Les commandes brutes gardent leurs chemins de session. Pour rejouer les copies
de sources, rétablir leur nom .sx dans un répertoire temporaire isolé avec un
Package.json approprié. Les compiler depuis le groupe de Spec. La sonde de
test doit être copiée sous Toolchain/Sources puis supprimée après son usage.
Les mesures brutes, leurs binaires et hashes sont scellés dans manifest.json.

Le [run natif 34679243046](https://github.com/Matanek/Silex/actions/runs/34679243046)
est vert : macOS X64, Linux ARM64/X64, Windows ARM64/X64, avec construction
intermédiaire Windows ARM64 également verte. Les journaux vérifient le SHA
exact et la fixture à dix-huit contrôles. Avec macOS ARM64 local, les six
cibles concernées disposent d'une preuve d'exécution native.

Le [run Intel 34679245713](https://github.com/Matanek/Silex/actions/runs/34679245713)
termine rouge sur les seuils de parité Clang, après qualification native verte.
Intel Core i7-8700B 3.20 GHz physique, Darwin 24.6.0, Apple Clang 17.0.0,
21 observations et six échauffements. Le SHA256 du ZIP correspond au digest
GitHub et les quinze exécutables correspondent au rapport.

Objects : baseline 16.251678 ms, candidat 16.321846 ms ; ratio apparié 0.989278,
intervalle 0.942869..1.049997. La dispersion Release dépasse 20 %, sa dérive
entre moitiés vaut 16.14 % et celle du ratio 10.93 %. Le verdict avant/après
est indéterminé. Arithmetic est également instable ; Flocking est stable et
neutre (ratio 1.015257, intervalle 0.942861..1.050420). Les binaires avant/après
d'Arithmetic et Flocking sont identiques : leurs fluctuations ne sont pas un
changement produit. Aucun gain ni perte Intel n'est déduit de ce run.

Une calibration des seuls binaires archivés est demandée : blocs ABBA/BAAB,
seize lancements par configuration et observation, avant/après, ordre inverse,
copies identiques et même fichier. Elle éprouve un protocole plus discriminant,
sans refaire la compilation ni modifier un seuil d'admission.
La Part 03 reste active.

## Contre-preuve Intel et correction de la politique cible

La [calibration 34680629827](https://github.com/Matanek/Silex/actions/runs/34680629827)
passe comme outil diagnostique, mais expose un ralentissement du candidat :
comparaison directe stable 1.066786, intervalle 1.039892..1.096095, soit 6.68 %
de temps supplémentaire. Le témoin même fichier est stable et neutre :
1.002319 (0.997500..1.007937). L'inverse est cohérent en direction, 0.934285,
mais instable, comme les copies identiques 1.002895. Le digest GitHub du ZIP
et les huit références exécutables des quatre contrôles sont vérifiés.
Le candidat universel b3273cc est donc rejeté pour X64 ; son gain ARM64 ne
justifie pas de conserver le ralentissement Intel.

La correction `72b81ab` sélectionne cette décision de coût à partir de
la cible demandée. ARM64 garde le cache scalaire ; X64 retrouve la politique
antérieure. Les trois benchmarks macOS ARM64 sont identiques à b3273cc et
les trois X64 à b8d01d7, avec et sans cache (dix-huit identités). Aucun nouveau
gain Intel n'est revendiqué. Cinq tests ciblés vérifient également l'IR pour
les six cibles ; les douze émissions et quatre exécutions macOS repassent.
Les portails finaux passent : 45/45 étapes check/test, 1995 tests internes et
184 tests de langage, 31/31 étapes de l'oracle, 74 tests de l'outil, 57
régressions fixes, huit scénarios, 64 erreurs entières et 43 conversions,
qualification X64 et robustesse complète. Les identités comparent chaque
paire dans le même contexte local isolé. La preuve native distante finale
reste à obtenir. Aucun gain Intel n'est revendiqué par cette correction.
