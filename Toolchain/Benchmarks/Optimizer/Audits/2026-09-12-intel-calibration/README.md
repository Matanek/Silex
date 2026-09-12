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
prédécesseur : une rotation n'équilibre pas les transitions. La calibration
suivante isolera les deux exécutables, équilibrera leurs transitions et
agrégera plusieurs lancements par observation, sans modifier l'admission.
