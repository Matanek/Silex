# Qualification physique Intel de la résidence scalaire X64

Candidat : `ebc20fb3bb2c397ee577f21b3a31083cc0f49c65`, publié avec
l’autorisation explicite de l’utilisateur sur la branche de Spec.
Campagne Intel : https://github.com/Matanek/Silex/actions/runs/34614632406
Portabilité initiale : https://github.com/Matanek/Silex/actions/runs/34614629374

## Correction et performance

Intel Core i7-8700B 3.20 GHz, macOS 15.7.9, Apple Clang 17, exécution X64
native (`translated: false`). Correction verte : 49 régressions fixes,
huit scénarios générés, 64 erreurs entières, 43 conversions Debug/Release.

Les 21 rotations après six échauffements échouent à la qualification de
performance. Ratios appariés observés Silex/Clang : Arithmetic 1.464907,
Objects 4.547570, Flocking 7.781661 (intervalle 7.366719..8.030247).
Chaque charge présente une dispersion excessive dans au moins une variante.
Flocking : médianes 3700.083 ms / 474.926 ms, dispersion Silex 10.6661 %,
Clang 20.4737 % ; la limite est 20 %. Le champ `evidence_mode: qualified`
indique le protocole demandé ; seul `qualification.passed: false` porte le
verdict. Aucun gain propre à la résidence scalaire n’est prouvé par une
comparaison entre ce run et la baseline précédente.

## Portée du comparateur

Le script historique `Benchmarks/Native/run.sh` construit Clang en `-O2`.
Ce résultat ne prouve donc pas la parité avec `-O3` demandée par la Spec.
Le Sample C++ utilise quatre float contigus (16 octets), contre quatre slots
de huit octets dans l’émission Silex (32 octets). Une comparaison à `-O3`
et layout équivalent reste à établir, sans effacer l’écart historique.
`flocking-steer-structural.json` complète les zones natives inspectées : ses
intervalles d’adresses peuvent comprendre des blocs de sortie et ne sont pas
une mesure de fréquence ni de gain. Les assembleurs correspondants sont
scellés dans l’audit `2026-09-11-x64-scalar-float-residence`.

## Portabilité initiale et suite

La matrice initiale échoue avant les smokes : le build exécute son admission
avec la mauvaise cible ou le mauvais répertoire courant ; une fixture LSP
suppose macOS ; plusieurs tests supposent des séparateurs ou dates Unix.
Les cinq journaux de jobs conservent ces diagnostics. Windows ARM64 natif
n’a pas démarré, son bootstrap ayant échoué. La réparation est une tranche
séparée ; cet audit ne la prétend pas validée.

La Part 03 reste active. La parité Intel et Physics ARM64 ne sont pas acquises.
Aucun tag, release ou changement du checkout principal n’est effectué.

## Intégrité

L’archive Actions `10270522831` a été téléchargée et vérifiée :
`a5c24fbf1b70b1f807ede30d2af51a66ff60b97c38c064282760891ad0934d64`.
Les observations, sorties vérifiées et hashes des exécutables sont dans
`artifact/optimizer-x64/campaign.json`. Le manifeste scelle tous les fichiers
conservés. Aucun lien temporaire de téléchargement n’est enregistré.
