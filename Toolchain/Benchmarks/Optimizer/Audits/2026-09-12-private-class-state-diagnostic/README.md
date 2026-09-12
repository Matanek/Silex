# Diagnostic de l'état privé de classe

Ce diagnostic ne qualifie aucune optimisation du compilateur et ne remplace
ni Objects ni son oracle. Le compilateur est le candidat `b8d01d7` inchangé.
Un témoin source séparé remplace seulement l'état du Counter privé par une
variable scalaire. Il supprime aussi son allocation et ses effets mémoire :
cette différence empêche d'en faire directement une transformation admise.
Le benchmark canonique reste intact et ses 6 000 000 imprimés sont conservés.

Sur Apple M3 Pro ARM64 physique, Darwin 25.6.0, 21 paires et six échauffements :
le témoin scalaire coûte 3.734042 ms contre 8.402833 ms pour le benchmark de
référence, ratio 0.444372 (0.443264..0.447871). Les critères de stabilité passent.
Clang à disposition identique coûte 2.072292 ms ; même ce témoin n'atteint pas
la parité. Aucun résultat Intel ni gain produit n'est déduit de ces données.

L'expérience réoriente le diagnostic vers la promotion de l'état privé de
classe, au-delà des seules copies de registres. Une implémentation éventuelle
doit prouver les alias et les échappements, garder les allocations et leurs
erreurs, les écritures observables, les durées de vie et les destructions.
Les sources, binaires, commandes et mesures brutes restent séparés des preuves
d'admission du candidat. Les seuils et références officiels n'ont pas changé.
