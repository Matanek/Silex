# Inlining régional des feuilles chaudes

Cette tranche part du noyau canonique `IntegrationKernel2D.sx`. La fonction
`integrate` exécutait deux appels directs à chaque itération alors que leurs
feuilles manipulent uniquement des références, du contrôle borné et les
frontières `Math.sqrt` et `Math.abs`, classées `pure` dans le modèle observable
de Silex.

L'ancien coût additionnait tous les scalaires matérialisés d'une fonction, y
compris ceux de chemins mutuellement exclusifs. Il rejetait ainsi la feuille
`integrate_velocity` avant que l'allocation native puisse juger la résidence
réelle. `CallSummary` conserve le compte cumulatif à des fins descriptives,
mais pénalise désormais le maximum de scalaires touchés dans un même bloc. Le
budget chaud passe de 192 à 320 et `InlineControlFlow` garde un plafond absolu
de 256. Une frontière directe ne cesse d'être une barrière que si son effet est
explicitement `pure`; les effets inconnus restent hors ligne.

Le contrat `HotReferenceLeafClosure.sx`, auparavant conservé comme refus de
pression, est le contre-témoin historique. Il exige maintenant que les deux
appels disparaissent. `PureMathReferenceInlining.sx` exige de même la
disparition de l'appel à travers `sqrt`. Les tests unitaires distinguent le
compte cumulatif du pic régional et vérifient séparément qu'une frontière
`unknown` interdit toujours l'expansion.

## Preuve ARM64 avant/après Silex

La référence produit est `45af0ae` (produit identique à `c3a4b39`) et le
candidat est `55f6b7df8a46baa94e34f89ade451b754b9d585a`. Les deux compilateurs
ont construit la même source scellée Physics. Les sorties complètes de 32 768
états sont identiques, SHA-256
`f6d5bf68307949686c87a6240d645438fce66653710382e32baf5236610b9725`.

Dans `integrate`, l'expansion passe de 36 à 244 instructions Machine, de deux
appels internes à zéro, et réduit le frame de 288 à 240 octets. L'allocation
finale garde 70 résidences GPR et 145 résidences flottantes. La hausse locale
du code est donc acceptée sur la preuve du chemin chaud et de la résidence,
pas sur le seul compte d'instructions.

La campagne physique M3 Pro alterne référence, candidat et témoin même fichier,
avec six échauffements et 21 triplets. Le candidat mesure 69,575 ms contre
79,204 ms pour Silex figé. Le ratio apparié médian vaut 0,877605 et son
intervalle unilatéral à 96,0823 % vaut 0,867004..0,888162. Le témoin même
fichier vaut 0,998693, intervalle 0,990310..1,003972. Le signal de 12,24 % ne
s'explique donc pas par l'ordre seul.

`PreparationKernel2D.sx` sert de contrôle voisin. Ses 32 768 états sont aussi
identiques, SHA-256
`8975b93c5bf19616ae02749bbf167c3fac89e67a073b9495c8732e94b3c5ce40`.
Son ratio candidat/référence vaut 1,017920, intervalle
0,984111..1,026214 : aucun gain ni aucune perte n'est attribué.

Le run GitHub ARM64 `34692143710` répète le signal sur un M1 natif
virtualisé. Le ratio Silex candidat/référence immédiate vaut 0,953041,
intervalle 0,932087..0,974105. Le témoin même fichier traverse la parité,
0,991893..1,029855, et les 32 768 états retrouvent le même SHA-256. L'amplitude
diffère de la machine locale, mais le signe du gain est répété sous deux
environnements. La comparaison externe demeure séparée : sur ce runner, Silex
reste 1,289227..1,322777 fois plus lent que Clang même disposition.

Le run Intel physique `34692147157`, sur Intel Core i7-8700B, confirme le
même signe. Le ratio candidat/référence immédiate vaut 0,961849, intervalle
0,950216..0,972457. Le témoin traverse la parité, 0,977059..1,014418. Les
32 768 états sont identiques dans cette architecture, SHA-256
`c0e39f760c6ca75e376de5d5d6c99fef230e309dda8e2a5b915c7a2cfec1f63c`,
et les deux exécutables font 66 080 octets. La comparaison externe mesure
encore un ratio Silex/Clang de 6,997326..7,440023. Cette distance absolue reste
ouverte ; elle ne change pas l'attribution d'un gain Intel de 3,82 % à la
transition Silex mesurée.

Les fichiers JSON conservent chaque ordre, temps, sortie, empreinte binaire et
intervalle. Les scripts sont les programmes exacts de mesure; leurs chemins
absolus documentent le worktree d'origine et ne constituent pas une interface
réutilisable.

## Portails

`zig build check --summary all` passe 44/44 étapes et 1 996/1 996 tests.
`zig build optimizer-gate --summary all` passe 31/31 étapes et 74/74 tests,
avec 57 régressions fixes et huit scénarios générés. Le target officiel
`optimizer-robustness-qualified` passe 144 paires, cinq triplets, 41 cas
natifs, quatre cas négatifs, le stress cache et le grand graphe.

La matrice native et les deux qualifications physiques externes sont
référencées dans `evidence.json`. Le manifeste SHA-256 est régénéré seulement
après leur verdict final.

Le run Intel général `34690143709` fait passer le corpus de régressions natives.
Arithmetic, Objects et Flocking produisent chacun un exécutable Release
strictement identique à la référence `c3a4b39`; leurs intervalles Silex A/B
traversent la parité. Le statut global rouge vient des comparaisons obligatoires
à Clang et de leur dispersion, pas d'une différence produit sur ces trois cas.

Le banc externe a révélé deux défauts avant workload. Le premier auditait une
histoire de 218 commits avec un fetch trop peu profond. Le second comparait les
hashes historiques de 41 régressions au fichier du candidat final. Les commits
`aac6e98` et `b257271` récupèrent l'histoire complète puis lisent chaque blob à
son `corrected_revision`; 15 hashes antérieurement réécrits retrouvent ainsi
leur valeur historique. `b257271` ajoute aussi un diagnostic physique qui prend
le Silex précédent comme référence, vérifie les états complets et alterne 21
triplets candidat/référence/témoin. `da1dedb` conserve les valeurs brutes quand
le témoin dérive et marque alors l'interprétation invalide. Enfin `b858fb2`
matérialise le `Package.json` du propriétaire depuis la révision scellée : les
dépendances ajoutées ensuite au dépôt du runner ne peuvent plus contaminer la
clôture.
