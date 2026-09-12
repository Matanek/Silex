# Valeurs dominantes et préparation complète

Le candidat `99472ac` étend la simplification SSA aux évaluations scalaires
identiques dominantes et aux champs numériques de paramètres de valeur stables.
Le corpus complet de préparation a été admis auparavant dans `106b170` : ses
26 champs sont tous observés, pour deux corps dynamiques, un corps fixe, deux
corps fixes, warm start activé/désactivé et mutation après retour (159 résultats).
`ValueModules` ajoute les limites de module, génériques, alias, zéro signé et NaN.

## Préconditions et causalité

La disponibilité exige une définition unique et une dominance réellement calculée
sur le CFG. Types, ordre des opérandes et drapeaux arithmétiques restent identiques.
Aucun calcul n'est déplacé avant son premier point d'exécution. Les fonctions
contenant appels, écritures adressables, formation d'adresse ou ressources sont
rejetées. Un affichage scalaire ordonné ne modifie pas ces valeurs. Les lectures
de classes, collections et agrégats locaux ne sont pas candidates.

Les tests protègent blocs sérialisés dans un autre ordre, prédécesseur inaccessible,
retour de boucle, disponibilité partielle, mutation par alias et première division
faillible. Les 820 lectures brutes de `prepare` deviennent 24 ; désactiver
`ssa_value_simplification` rétablit 56 lectures. Ces nombres concernent l'IR ;
ils ne sont pas des chargements natifs ni une mesure de parité.

EarlyCSE, au SHA LLVM `3623fe661ae35c6c80ac221f14d85be76aa870f1`, distingue
la table de valeurs scalaires dominantes des générations mémoire invalidées par
écritures/événements d'ordre. Les sources et tests épinglés, déjà scellés dans
l'audit `2026-09-11-scalar-expressions`, ont été relus pour cette distinction.
La présente analyse Silex conserve un contrat plus étroit ; elle ne prétend pas
implémenter MemorySSA ou traverser des effets inconnus.

## Validation

`zig build check test optimizer-gate optimizer-robustness-qualified install` :
53 étapes et 2 136 tests verts ; 183 tests du langage, 25 cas de corpus,
46 régressions natives fixes, huit générées, 128 différentiels internes et 32 LLVM.
La robustesse conserve 144 paires, cinq triplets, 41 cas natifs et quatre négatifs,
puis les stress de cache et de packages. Les budgets protégés sont inchangés.

Les deux nouveaux témoins concordent dans 24 émissions, dont huit exécutions
macOS Debug/Release ARM64 et X64 Rosetta. Linux/Windows ne sont que des émissions.
Huit exécutions LLVM brut/Release à O0/O3 des deux témoins de correction concordent.
Les variantes longues ont une observation booléenne exacte du résultat final :
le pont refuse explicitement l'affichage décimal flottant (`UnsupportedType`).
Cette adaptation de l'observation, visible dans les fichiers `Checked.sx.txt`,
ne change aucun calcul et ne sert pas au chronométrage natif.

Les premiers journaux rouges restent archivés : une fixture avait une forme
incorrecte d'emprunt ; une autre attente exposait l'exclusion trop large des
copies primitives. Un test Debug qui provoque volontairement SIGSEGV a reçu une
fois SIGKILL ; sa cause n'est pas attribuée. Sa reprise inchangée, puis le portail
complet final, sont verts. Aucun test de signal ni seuil n'a été assoupli.

## Coût et contre-preuves

Tous les chronométrages sont diagnostiques sur Apple M3 Pro, macOS ARM64 Release,
avec démarrage inclus, six échauffements et 21 observations alternées/rotatives.
Les fichiers JSON contiennent chaque observation, les empreintes et la dispersion.

- Préparation complète, un million d'itérations : 88.099 ms avant, 87.825 ms
  après, ratio apparié 0.994102, MAD 0.007091. Aucun gain temporel établi.
  Le partage manuel donne 86.620 ms. Le corps natif passe de 71 à 40 chargements,
  mais reste sans appel et conserve une grosse frame (1680 vers 1664 octets).
- Quatre récurrences scalaires, quatre millions d'itérations : huit divisions
  natives deviennent quatre. Médianes avant/après 70.786/69.552 ms, ratio
  0.981893, MAD 0.019708 : tendance favorable, résultat temporel non concluant.
  La première campagne ayant chevauché une compilation est explicitement
  conservée sous `contaminated` et exclue du verdict.
- La récurrence unique ne gagne pas avec le partage manuel : sa chaîne de
  dépendance limite l'intérêt du doublon supprimé. Ce non-gain reste conservé.
- Placer manuellement tout le corps de préparation dans l'appelant régresse :
  88.495 vers 92.720 ms, ratio 1.047192, MAD 0.003709. Ce contrôle rejette une
  extension indiscriminée de l'inlining ; le consommateur n'est pas réécrit.

Les profils `hot-budget` non enregistrés émettent leurs artefacts puis retournent
`HotFunctionNotRegistered`. Ils sont des inspections, pas des budgets acceptés.
Les gains structurels motivent la réutilisation de valeurs ; ils ne ferment pas
le coût ABI, les copies, la résidence ou la parité temporelle du stage complet.
Ces coûts cibles sont à confronter aux contrôles conservés, dans le travail machine
et les campagnes de consommateurs. Le défaut de débordement X64 préexistant
reste ouvert dans l'audit `2026-09-11-dead-scalar-storage`.

Les logs, IR et TSV sont conservés octet pour octet. Les sources des expériences
portent `.sx.txt` pour ne pas entrer accidentellement dans le corpus automatique.
