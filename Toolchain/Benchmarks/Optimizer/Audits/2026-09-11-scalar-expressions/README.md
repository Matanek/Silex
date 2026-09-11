# Réutilisation locale des expressions scalaires

Implémentation : `f25bd782a037bb8fc1f1b82f2283feb3a1230c97`.
Le manifeste scelle les sources, le compilateur mesuré, les commandes, les
réductions et les observations. Le parent reste le témoin avant cette passe.
Les exécutables temporaires sont identifiés par leurs empreintes dans les JSON.

## Cause et transformation

La réduction d'Integration calcule deux fois `step * inverse_mass`, même après
propagation des lectures. Les deux opérandes sont des instantanés scalaires
immuables ; une écriture entre ces calculs ne change pas leurs valeurs.
La numérotation locale réutilise le premier résultat, avec identité unique des
définitions, ordre des opérandes, type et drapeaux arithmétiques identiques.
Les appels, releases et frontières de blocs coupent la disponibilité. Les
lectures mémoire ne participent pas à cette table. Il n'y a ni réassociation
flottante, ni commutativité supposée, ni suppression du premier calcul faillible.

L'implémentation et les tests EarlyCSE épinglés distinguent également valeurs
pures et mémoire, et excluent les opérations flottantes contraintes dont
l'environnement doit rester observable. Les liens et empreintes figurent dans
le manifeste ; les sources LLVM ne sont pas recopiées dans ce dépôt.

`scalar-before-test.log` conserve l'échec structurel avant correction : deux
produits au lieu d'un, avec observations sémantiques déjà concordantes. La
régression autonome couvre forme directe, helper, générique, écritures entre
instantanés, nouvelle lecture après mutation, division entière, zéro signé et
NaN. Le contrat retire quatre produits vers deux ; désactiver
`ssa_value_simplification` rétablit quatre produits. La voie relisant une valeur
modifiée conserve ses deux produits. Les tests internes protègent aussi les
appels, redéfinitions, drapeaux distincts et frontières de blocs.

## Vérification

- 53 étapes et 2 130 tests passent, dont 183 tests du langage ; 23 cas de
  corpus, 44 régressions natives fixes, huit scénarios générés, 128 différentiels
  internes et 32 LLVM.
- Robustesse : 144 paires, cinq triplets, 41 cas natifs, quatre négatifs et
  stress cache/packages. Les budgets existants restent inchangés et verts.
- Douze émissions pour les six cibles ; Debug/Release exécutés sur macOS ARM64
  et sous Rosetta X64. Les huit observations de la régression concordent.
- Quatre exécutions LLVM brut/Release à O0/O3 concordent pour la régression.
  Huit autres concordent pour les formes longue répétée/partagée. Les lignes
  LLVM avertissant d'un triple normalisé par Clang sont conservées.
- Scan : 55 concordances d'interprétation, 30 émissions LLVM dans les deux
  modes. L'émission seule n'est pas une preuve d'exécution.
- La comparaison à 11 paires reste diagnostique ; ses observations ordonnées
  et son profil sont archivés. Aucun seuil de parité n'est changé.

La réduction de vues conserve désormais deux additions vérifiées au lieu de
trois : une addition identique est réutilisée. Les preuves antérieures qui
comptaient trois gardes restent des observations historiques exactes de leurs
candidats. La première évaluation et son erreur restent observables.

## Coût isolé sur ARM64

La charge longue répète 32 intégrations d'un million d'itérations, en réinitialisant
les corps entre intégrations et en observant les six résultats de chacune.
Elle évite de prolonger artificiellement la récurrence flottante. Le consommateur
Physics et ses sources n'ont pas changé.

Six rotations d'échauffement précèdent 21 rotations mesurées des trois binaires :

| Configuration | Médiane | MAD |
| --- | ---: | ---: |
| Compilateur précédent, expression répétée | 248.361875 ms | 0.458667 ms |
| Compilateur précédent, partage manuel témoin | 231.751667 ms | 1.135167 ms |
| Nouveau compilateur, source répétée inchangée | 231.480542 ms | 0.429791 ms |

Le ratio apparié après/avant médian est 0.931970, sa MAD 0.004089 et son
déplacement entre demi-fenêtres 0.000765. Le ratio après/témoin partagé est
0.999552. Le gain de cette réduction est donc d'environ 6.8 % ; le démarrage du
processus reste inclus. Les observations ne qualifient ni un stage complet,
ni le coût LLVM, ni un CPU X64 physique.

L'IR machine passe de 22 à 21 opérations binaires avec une copie supplémentaire ;
le natif coalesce cette copie. Le corps ARM64 passe de 45 à 44 instructions,
de sept à six `fmul`, conserve six `fmadd`, zéro appel et une frame de valeurs
nulle. Le témoin partagé émet les mêmes nombres. Les commandes `hot-budget`
produisent leurs profils avant de refuser ces noms non enregistrés avec
`HotFunctionNotRegistered` : ces fichiers servent à l'inspection, et ne sont
pas des budgets acceptés. Aucun budget n'a été créé ou relâché pour les faire passer.

## Frontières

Les fichiers métamorphiques conservent les comptes bruts actuels de l'oracle.
Ils comptent aussi des helpers devenus inaccessibles ; leurs écarts ne prouvent
pas à eux seuls un surcoût exécuté. Cette attribution doit être clarifiée avant
une décision d'inlining. Les analyses inter-blocs et les politiques de pression
plus larges ne sont pas qualifiées par cette passe locale.

Le défaut X64 préexistant de garde de débordement, réduit dans l'audit précédent,
reste attribué au travail machine. Aucun résultat présent ne le déclare corrigé.
Les logs et TSV sont conservés octet pour octet, y compris espaces de compilation
et colonnes vides ; le manifeste protège ces octets.
