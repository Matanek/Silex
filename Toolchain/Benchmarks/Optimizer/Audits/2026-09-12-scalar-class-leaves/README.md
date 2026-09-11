# Feuilles scalaires de classe

Candidat `6b3f302b580acaf11a3375b2ae421be1140f525b`, référence
`737fc8c9f9525cf1f7fe3f13af945eb88e63a58b`.
Compilateur SHA-256 :
`e10ef7015b4c91914e54b1ab26928eae5cf10010156dae353f9dcb1e5badfd37`.

L’inliner admet une feuille à un bloc qui retourne une identité de classe
issue de ses paramètres et ne lit/écrit que des champs numériques ou booléens.
Les valeurs de classe doivent avoir le type de retour. Allocation, ressource,
adresse, retain/drop, autre appel et sortie observable refusent la nouvelle
extension. Le budget d’effets et de pression reste appliqué ; les anciennes
décisions ne changent pas. Le clonage conserve les field_store et leurs alias.

Le test ciblé compare les sorties et mutations observées via un alias,
vérifie la disparition du seul appel admissible et le maintien d’un appel
avec sortie. Désactiver la nouvelle admission fait échouer ce test.
Le témoin natif donne dix lignes vraies en Debug/Release sur macOS ARM64/X64 ;
les douze émissions couvrent les six cibles, y compris un remplacement de
champ de ressource qui reste hors de cette extension.

Portails verts : 49/49 étapes, 2163 tests internes et 183 tests langage ;
oracle 31/31, 74 tests, 56 régressions fixes, huit générées, 64 erreurs entières
et 43 conversions sur ARM64 et X64 local sous Rosetta. Robustesse 144 paires,
cinq triplets, 41 natifs, quatre négatifs, cache et grand graphe verts.

Objects change sur les deux architectures. Le désassemblage du premier corps
encodé, calculate, perd les deux sites d’appel de Counter.add, soit un appel
par itération. Les comptes du corps entier sont conservés comme métriques
statiques, sans confondre taille totale et coût de boucle. Arithmetic et
Flocking sont identiques à 737fc8c ; les deux noyaux Physics ont un code
machine identique. Leurs empreintes complètes peuvent différer du fait des
noms d’exécutable : aucune identité complète n’est revendiquée pour Physics.

Mesure Objects ARM64 physique, six échauffements et 21 rotations :
8,528 → 8,571 ms, rapport 1,001968, intervalle 0,976609..1,012414.
La comparaison est stationnaire et neutre. Aucun gain ARM64 n’est établi ;
la parité reste rouge. Les campagnes natives et Intel exactes sont lancées,
avec 737fc8c comme référence Intel. La Part 03 reste active.

L’outil hot-budget échoue déjà sur l’IR d’entrée de la référence inchangée
avec DefinitionDoesNotDominateUse, en sélectionnant calculate puis main.
Ces refus sont conservés ; ils ne sont pas utilisés comme preuve de ce
candidat. Les appels sont vérifiés dans les exécutables réellement compilés,
et l’oracle cumulatif reste vert.

The native matrix run 34657769771 passed all six executed jobs on the exact
6b3f302 candidate: Linux X64/ARM64, macOS X64, Windows X64/ARM64 and the
Windows ARM64 bootstrap. Job logs are decoded connector text with LF line
endings. The separate physical Intel timing campaign remains pending.
