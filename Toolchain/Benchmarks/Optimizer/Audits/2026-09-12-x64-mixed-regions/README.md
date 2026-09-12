# Résidence entière dans les boucles mixtes X64

Candidat `901c6f5594841a277da00c53c29051bb7ab23076`, baseline
`40dc12052f4d03b646ba2210ec5b15013f338f77`. Le compilateur local figé porte
SHA-256 `171b92a2f851851982b75c2b9df9313c02e6014f98911a6f76672e8dbc8dfdeb`.

Les opérations flottantes et conversions permettent la résidence de valeurs
entières indépendantes. Leurs entrées/sorties, les agrégats, les retours et
les paramètres des nouvelles signatures restent épinglés à leur place ABI.
Le test réduit échoue avant ; les 59 tests X64 passent et retirer la protection
des paramètres fait échouer le témoin. FloatMemoryResidence donne 22 sorties
vraies, y compris un appel à neuf arguments avec deux vues.

Les portails passent : 2167 tests internes et 184 tests de langage ; 31 étapes
oracle, 74 tests, 57 régressions fixes, huit scénarios, 64 erreurs entières et
43 conversions ; robustesse 144 paires, cinq triplets, 41 cas natifs et quatre
négatifs, avec stress cache/graphe. La qualification X64 locale utilise Rosetta
et prouve seulement la correction. Les 28 émissions et 12 exécutions macOS
ARM64/X64 Debug/Release ont des sorties exactes.

Les trois binaires généraux ARM64, Arithmetic X64 et Objects X64 sont identiques
à la baseline. Flocking X64 conserve 1862 instructions dans le texte complet
mais réduit les références à la pile de 651 à 583. La sonde suivant le pipeline
X64 réel (IR Release puis lowering pile debug et allocation X64) confirme
0 → 23 résidences entières dans calculate et 0 → 12 dans steer ; leurs 73 et
55 résidences FP restent identiques. La première sonde erronée appliquait
l'allocation X64 à une représentation ARM64 déjà allouée : ses chiffres ne sont
pas des preuves et ne sont pas utilisés ici. Les sorties HotFunctionNotRegistered
sont attendues après l'écriture du diagnostic : ces fonctions ne sont pas
inscrites au registre de budgets ARM64. Elles ne constituent pas un portail.

Les validations natives macOS/Linux/Windows X64 et la mesure Intel physique
sont dispatchées sur le SHA exact. Aucun gain ni parité n'est revendiqué en
attendant ces résultats. Les seuils de stabilité et de parité sont inchangés.

## Exécutions natives X64 validées

Les trois exécutions du SHA exact sont vertes : macOS X64 `34663803459`
(job `103471551999`), Linux X64 `34663804874` (job `103471555256`) et
Windows X64 `34663806275` (job `103471559207`). Chaque cible exécute les
témoins Debug/Release, dont les 22 sorties de FloatMemoryResidence.
Les journaux et métadonnées sont scellés ici. La mesure Intel
`34663807514` reste distincte de ces preuves de correction.

## Mesure Intel : aucun gain démontré

Le run [34663807514](https://github.com/Matanek/Silex/actions/runs/34663807514)
passe les régressions puis échoue à la parité. Intel Core i7-8700B 3.20 GHz
physique, Darwin 24.6.0, Clang 17 ; 21 paires, six échauffements, seuils inchangés.
Les critères de dispersion et de dérive passent pour les trois paires.
Flocking reste neutre : ratio 1.010630, intervalle 0.985352..1.033477.
Arithmetic reste neutre : ratio 1.031777, intervalle 0.993995..1.076579.
Objects présente 1.044659 (1.029623..1.048213), mais les exécutables avant et
après sont strictement identiques ; Arithmetic est également identique.
Ce contrôle invalide l'attribution de l'écart Objects au compilateur. Le
passage des seuls critères statistiques ne transforme pas cet écart en
régression du code. Aucun gain n'est revendiqué et la parité reste rouge.

L'artefact 10288229621 et les quinze empreintes de binaires sont vérifiés.
SHA-256 du ZIP :
`011eb9b22b908bbaa00518b23aa21d8d807566ed7365b1be4b49b7363996c5ea`.
Les rapports, journaux, échantillons et exécutables sont conservés ici, ainsi
que la comparaison binaire et les désassemblages du contrôle identique.
