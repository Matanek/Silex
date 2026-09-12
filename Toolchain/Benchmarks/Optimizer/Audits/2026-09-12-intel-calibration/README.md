# Calibration diagnostique Intel des exécutables archivés

Workflow `34666742724`, outil `37999a44323d6444053e29037e93376f9bd96171`,
job `103480043752` exécuté avec succès. Aucun compilateur reconstruit :
les exécutables viennent du run `34664959587`, candidat `b8d01d7`, baseline
`901c6f5`, dont les quinze identités ont été vérifiées avant toute mesure.
Intel i7-8700B physique, Darwin 24.6.0, 21 paires, six échauffements.

| Contrôle | Ratio médian | Intervalle | Stabilité |
| --- | --- | --- | --- |
| candidat / baseline | 0.918389 | 0.895647..0.958685 | dispersion et dérive baseline |
| baseline / candidat | 1.153919 | 0.996125..1.182842 | dispersion des deux |
| deux copies identiques | 1.010319 | 0.932819..1.039510 | dispersion baseline |
| même fichier sous deux étiquettes | 1.026076 | 0.984479..1.073731 | dispersion des deux |

Aucun contrôle n'est qualifié. L'écart initial de +4.20 % sur Objects n'est
ni confirmé ni réfuté par cette expérience. Les sorties exactes restent
identiques. Le succès du workflow indique la collecte complète des témoins,
non une admission de performance. Aucun seuil n'est modifié.

L'artefact `10289537337` possède le SHA-256
`21d547c378cda49d7cb63e3f0e0c2f061f8ac670792b73e6696b61f18662c910`.
Les vingt identités de fichiers référencées par les quatre contrôles sont
vérifiées après téléchargement (le dernier réutilise le même fichier).

Le chronomètre inclut lancement et attente du processus. La rotation des cinq
configurations répartit leur position, mais garde majoritairement le même
prédécesseur : une rotation n'équilibre pas les transitions. Le contrôle suivant isole
les deux exécutables, équilibre leur ordre et agrège plusieurs lancements
par observation, sans modifier l'admission.

## Contrôle équilibré terminé

Outil `c9e3a73cd60301d0cdd4b2ad792fc85c76abb671`, workflow `34667012897`,
job `103480855384` : collecte achevée avec succès. Onze tests Python,
validation YAML, dix-sept corps Bash et collecte native de processus passent.
Les sources et seuils du portail `campaign.py` sont inchangés.

Chaque observation agrège seize lancements par configuration, dans des blocs
ABBA/BAAB alternés, avec seulement les deux exécutables comparés. Les 21
observations suivent six blocs d'échauffement. Les 2688 lancements mesurés
(4 contrôles × 21 observations × 32 processus) restent individuellement
conservés ; chaque sortie est vérifiée, les sommes et huit identités de
binaires référencées sont recontrôlées après téléchargement.

| Contrôle | Ratio médian | Intervalle | Stabilité |
| --- | --- | --- | --- |
| candidat / baseline | 1.020490 | 0.970443..1.055425 | dispersion et dérive des deux |
| baseline / candidat | 0.993019 | 0.988348..1.001610 | dispersion et dérive des deux |
| deux copies identiques | 1.001725 | 0.989436..1.010240 | dispersion et dérive des deux |
| même fichier sous deux étiquettes | 0.999458 | 0.987257..1.009260 | verte, neutre |

Le contrôle d'un même fichier devient neutre et stable. Cela ne qualifie pas
les trois autres séries : les dispersions du couple candidat/baseline vont
encore de 40.83 % à 109.09 %. L'écart initial de +4.20 % demeure non attribué.
Ni régression prouvée, ni gain, ni parité ne peuvent être déduits de ces
contrôles. Les intervalles sont ceux du protocole existant ; aucune division
par le ratio du témoin ni correction a posteriori n'est appliquée.

L'artefact `10289433060` a pour SHA-256
`c4120a1f94aab2018b23a2a8d63eea4a183b6fd76a7ad380577ba9a704c09b2e`.
Les données brutes sont dans `balanced-intel/`. La campagne diagnostique est
terminée. Une nouvelle attribution exige une série Intel stationnaire avec
son contrôle identique ; répéter le même run sans changement discriminant
n'est pas une preuve supplémentaire. Les déficits de parité générale restent
indépendamment ouverts, comme documenté dans l'audit des opérandes entiers.
