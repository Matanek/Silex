# Longueurs privées à travers le contrôle de flot

Candidat `737fc8c9f9525cf1f7fe3f13af945eb88e63a58b`, référence
`886cc17e59203c7c6b42190ddfe28239a0ece81d`.
Compilateur local SHA-256 : `f69d480a52bac15b07eee24c03500eab3c275f85aa5dd3b62c957461640ab103`.

L’analyse portable prouve une longueur de liste scalaire à définition unique
lorsque toutes ses utilisations sont des observations directes ou des
opérations de comptage de références. Toute copie, vue, adresse, mutation,
transmission ou retour de la liste refuse la preuve. Un drop n’est admis
qu’en dernière utilisation dans un bloc qui retourne. Les éléments restent
soumis à l’analyse locale existante.

Trois tests ciblés passent ; rétablir l’ancienne analyse fait échouer le test
positif. Le portail passe 49/49 étapes, 2162 tests internes et 183 tests langage.
L’oracle passe 31/31 étapes, 74 tests, 55 cas fixes, huit générés, 64 erreurs
entières et 43 conversions ; X64 local sous Rosetta passe également 55/8/64/43.
Robustesse : 144 paires, cinq triplets, 41 natifs, quatre négatifs, stress
cache et grand graphe verts. Les refus initiaux SealedReportConflict sont
conservés : les anciens rapports immuables ont été renommés par empreinte,
puis les nouveaux rapports ont été produits sans modifier le compilateur.

Le témoin donne dix lignes vraies dans les deux modes sur macOS ARM64/X64.
Les douze émissions couvrent les six cibles. Objects change sur ARM64/X64 ;
Arithmetic et Flocking restent byte-identiques à 886cc17.
La première mesure Objects ARM64, six échauffements et 21 rotations, ne
qualifie aucun gain : médianes avant/après 7,885/8,907 ms, rapport 1,152049,
référence instable. Aucun verdict de gain ou de régression stationnaire n’est
prononcé. La parité est rouge. Les sources canoniques ne sont pas changées.

Pour Physics, les exécutables avant/après recompilés avec les mêmes chemins
absolus ont un code désassemblé identique (hors nom de fichier). Les empreintes
complètes diffèrent ; elles ne sont pas présentées comme identiques. Les
32 768 états de chaque noyau restent strictement identiques ; Preparation
reste à 2,7e-7 de Clang et le rejeu complet d’Integration à 1,14e-5.
Les exécutables 225ba12 antérieurs ont des chemins de diagnostic différents :
aucune nouvelle mesure Physics n’est attribuée à cette analyse.

La campagne Intel compare ce candidat à 7bd153c. La sélection SSE change
Flocking ; les longueurs privées changent Objects ; Arithmetic est identique.
Les preuves d’identité des exécutables distinguent ces contributions.
La [matrice native](https://github.com/Matanek/Silex/actions/runs/34655625766)
passe ses six jobs sur le SHA exact ; journaux et identifiants joints.
La [mesure Intel](https://github.com/Matanek/Silex/actions/runs/34655627073)
est terminée sur Intel i7-8700B physique, macOS 15.7.9, Clang 17.
Six échauffements et 21 rotations sont stationnaires pour les trois cas.
Arithmetic est neutre : ratio après/avant 1,017715, intervalle 0,993129..1,037888.
Objects passe de 22,925 à 17,676 ms : ratio 0,771044, intervalle
0,758618..0,786877, soit 22,90 % de gain. Flocking passe de 1790,500 à
1442,295 ms : ratio 0,798774, intervalle 0,781774..0,813916, soit 20,12 %.
Les ratios Silex/Clang -O3 restent 1,262750, 3,789117 et 3,147937 : la parité
est rouge sur les trois cas. Les régressions 55/8/64/43 passent.

Les 15 exécutables de l’artefact `10285447351` ont été vérifiés contre le
rapport ; ses 48 fichiers extraits sont conservés. SHA-256 du ZIP :
`93a7261098f5788af1e41b75327f42cebb9337a319170129be8ab3399e5fb177`.
La Part 03 demeure active.
