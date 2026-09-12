# Lectures dominantes des champs empruntés — 11 septembre 2026

Candidat : `b7f8603` ; référence : `270a53c9afd6504ea91d070d2d0079049d7ba1d9`.

L’optimisation de valeurs dominantes accepte maintenant les lectures scalaires
projetées directement depuis un paramètre adresse stable, dans une fonction
sans écriture ni appel. La clé distingue racine, structure, champ et type.
Une réaffectation du paramètre, une écriture possiblement aliasée, un appel ou
une disponibilité seulement conditionnelle interdit le partage.

Cette correction portable complète une dépendance exposée par le vrai graphe
d’appel de Physics : l’emprunt d’élément transforme les lectures de champs de
valeur en lectures de référence, jusque-là exclues du partage dominant.
Le profil part de `main`, conservant cette convention et le retour directement
transmis à la vue. Le corps ARM64 passe de 184 à 147 instructions, de 62 à 26
chargements et de 32 à 28 stockages ; la frame native passe de 1472 à 1424 octets.
Ces comptes sont statiques, branches comprises ; les paires comptent deux mots
dans les métriques de trafic séparées.

## Mesure et contre-épreuves

21 rotations avant/après/Clang après six échauffements, ARM64 physique :
522.648 → 452.515 ms ; Clang au même layout 259.322 ms. Ratio apparié après/avant
0.863300, intervalle 0.858861..0.877578, MAD 0.013279, décalage entre demi-fenêtres
1.71 %. Gain établi de 13.7 %. Après/Clang 1.740196, intervalle
1.725271..1.755166 : la parité demeure rouge. Comparer les candidats au sein de
ces rotations ; les temps absolus de campagnes antérieures ne sont pas leur
référence appariée.

Les 32768 états à 26 champs restent exactement identiques. Écart maximal avec
Clang 2.7e-7, dans les tolérances existantes. Les sources et états de référence
sont scellés dans l’audit voisin `2026-09-11-partial-parameter-residence`.
Aucun seuil, algorithme, layout ou contrat de benchmark n’a été modifié.

Une nouvelle régression permanente observe 28 résultats : branches, snapshots,
alias modifiable, NaN, zéro signé et champs de types différents. Sept variantes
IR contrôlent le partage et ses refus. `check test install` : 49/49 étapes,
2145/2145 tests et 183 tests de langage. Portail et robustesse : 31/31 étapes,
74/74 tests chacun ; 144 paires, cinq triplets, 41 cas natifs, quatre négatifs.
ARM64 physique et X64 sous Rosetta passent 48 cas fixes, huit cas générés,
64 erreurs entières et 43 conversions en Debug/Release.

Le profil hors registre produit ses artefacts puis échoue avec
`HotFunctionNotRegistered` : il ne constitue pas un budget admis. Les résultats
X64 présents ici prouvent la correction, sans prétendre mesurer un CPU Intel.
La campagne physique distante du candidat antérieur `270a53c9` est indépendante.

## Coût restant identifié

La réduction des 26 sorties garde ses champs en registres dans Clang ; Silex
les stocke en pile autour de son chemin d’affichage à appels multiples. La
politique ARM64 limite en outre toute fonction avec appels à quatre registres
flottants conservés. Distinguer résidence entre appels, valeurs réellement
vivantes à travers un appel et sauvegardes propres aux chemins avant d’étendre
l’allocation ou de réintroduire l’expansion des gros noyaux.
