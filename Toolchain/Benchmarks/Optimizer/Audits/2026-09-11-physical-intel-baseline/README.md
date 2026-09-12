# Baseline Intel physique de la Part 03

Candidat publié et exécuté : `270a53c9afd6504ea91d070d2d0079049d7ba1d9`.
Publication expressément autorisée par l’utilisateur, sur la seule branche de
Spec. Les commits locaux ultérieurs ne sont pas couverts par cette autorisation.

Workflow : https://github.com/Matanek/Silex/actions/runs/34606627827
Job : `103286530449`. Intel Core i7-8700B physique, macOS 15.7.9, Clang 17.
Les régressions natives réussissent : 47 cas fixes, huit scénarios générés,
64 erreurs entières et 43 conversions. Le workflow échoue sur la performance.

Campagne : 21 rotations, six échauffements, sorties vérifiées, observations
brutes et hashes des exécutables dans `artifact/optimizer-x64/campaign.json`.
Flocking respecte les seuils de stabilité mais reste 9.618221 fois plus lent
que Clang (intervalle 9.089862..9.781025). Médianes : 3661.341 ms et 389.263 ms.
Arithmetic (ratio observé 1.381544) et Objects (4.846640) échouent aussi aux
seuils de dispersion ; leurs ratios ne sont pas des mesures qualifiées.
Aucun de ces trois témoins ne passe le contrat de parité. Le résultat ne
qualifie ni les commits locaux suivants ni Physics Preparation/Integration.

L’archive GitHub est conservée exactement et son SHA-256 vérifié contre les
métadonnées : `b4a8e1b36539c635a0af28d1c22a08ad1d0683e082f2b1468de1df4ca02ec9b6`.
Les cinq fichiers extraits, le journal du job et les preuves de publication
sont scellés par le manifeste. Aucun lien temporaire d’accès n’est conservé.
