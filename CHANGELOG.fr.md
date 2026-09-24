# Journal des versions de Silex

Ce journal aide à décider s'il faut mettre Silex à jour et à préparer les
adaptations nécessaires. Chaque candidat de release ajoute d'abord son entrée
française, puis sa traduction anglaise dans `CHANGELOG.md`. Les changements en
cours sont consignés sous `## [Unreleased]`, puis regroupés lors de la release.
Cet historique éditorial commence à la version 0.44.1.

## [0.47.0] - 2026-09-24

### Pourquoi mettre à jour ?

Cette version rétablit le backend natif comme choix par défaut sur tous les
hôtes, y compris macOS ARM64. Elle réduit des coûts d'allocation et de copie
dans les programmes natifs et corrige des erreurs de durée de vie et de
génération de code dans les deux backends.

### Changements

- `run`, `test` et `compile` sans `--backend` choisissent désormais `native`.
  LLVM reste disponible explicitement sur macOS ARM64 avec `--backend llvm`.
- Sur macOS ARM64, les petites allocations natives utilisent le tas système
  (`calloc`/`free`) au lieu d'un mapping mémoire par allocation. Un
  [diagnostic CCD à travail fixe](https://github.com/Matanek/Silex-Lib-GFX.Physics/blob/c9f85526488f0dbed0842a22ca484d06b1f46772/Benchmarks/Baselines/2026-09-24-native-heap.md)
  en Release, avec 16 corps, quatre parois mobiles et 24 pas, mesure
  16,48–17,06 ms/pas avant et 1,70–2,51 ms/pas après cette modification,
  à code physique identique et états finaux identiques. Ces deux paires de
  mesures isolent le coût de l'allocateur : elles ne constituent ni un gain
  général garanti, ni une comparaison complète entre versions publiées.
- Le backend natif ARM64 réduit les copies d'agrégats imbriqués, admet davantage
  de régions scalaires et optimise des noyaux à vues vérifiées. Il préserve
  correctement les registres SIMD et les composantes flottantes lors des appels.
- LLVM corrige la copie des graphes de classes récursifs, l'égalité des enums
  à données, les appels hérités, les ressources, les collections et callbacks.
  Les deux backends renforcent la collecte des cycles et la préservation des
  descendants encore vivants.
- Le compilateur libère plus tôt les données d'analyse devenues inutiles et
  borne la mémoire temporaire de certaines analyses et évaluations.

### Impact et migration

Sur macOS ARM64, ajoutez `--backend llvm` si vous souhaitez conserver le backend
par défaut de 0.45–0.46. Ailleurs, le choix par défaut ne change pas. Recompilez
vos programmes pour bénéficier des corrections ; aucune migration syntaxique
n'est requise. Les chiffres ci-dessus ne s'appliquent qu'au diagnostic natif
macOS ARM64 indiqué, pas aux autres architectures ni aux FPS d'une application.

## [0.46.1] - 2026-09-19

### Pourquoi mettre à jour ?

Cette version évite qu'une ancienne installation de Silex bloque
`silex login` lorsque son dossier d'authentification possède encore des
permissions trop larges.

### Changements

- Le client resserre automatiquement à `0700` un ancien dossier de stockage
  qui ne contient pas encore de credential du registre.
- Il continue de refuser les liens symboliques et tout credential trouvé dans
  un dossier qui aurait pu être lu par un autre utilisateur local.

### Impact et migration

Aucune intervention manuelle n'est nécessaire lorsque le dossier ne contient
pas encore de credential du registre. Un credential déjà présent sous des
permissions permissives reste refusé et doit être révoqué avant une nouvelle
connexion.

## [0.46.0] - 2026-09-18

### Pourquoi mettre à jour ?

Les auteurs qui publient régulièrement des packages peuvent conserver leur
connexion au registre Cloudflare sans réautoriser GitHub chaque jour.

### Changements

- `silex login` conserve désormais un accès de 30 jours. Une publication ou
  une nouvelle invocation de `silex login` le renouvelle automatiquement
  lorsqu'il reste au plus sept jours, jusqu'à 90 jours après l'autorisation
  GitHub initiale.
- `silex logout` continue de révoquer l'accès côté registre et de retirer
  la copie locale lorsque le service est accessible.

### Impact et migration

Le registre officiel conserve le parcours de 24 heures des clients 0.45.0.
Mettez Silex à jour pour bénéficier de la connexion prolongée. Une
réautorisation GitHub reste nécessaire après 30 jours d'inactivité ou au
plus tard après 90 jours ; aucun dépôt Git ni droit supplémentaire n'est
demandé. Les installations publiques restent anonymes.

## [0.45.0] - 2026-09-18

### Pourquoi mettre à jour ?

Cette version prépare la publication et l'installation des packages depuis le
registre Cloudflare. Elle permet de publier l'instantané d'un dossier local,
sans dépôt Git, et de conserver les versions installables indépendamment du
dépôt de leur auteur. Elle apporte aussi de nouvelles expressions au langage
et étend le backend LLVM qualifié sur macOS ARM64.

### Changements

- `silex login` connecte l'auteur avec son identité GitHub sans accès à ses
  dépôts ; `silex logout` révoque l'accès local.
- `silex publish <dossier>` envoie les sources et les artefacts déclarés au
  registre. `--dry-run` montre les inclusions, exclusions et le condensat de
  l'instantané sans réseau ni publication.
- `silex install` reconnaît le protocole du registre Cloudflare lorsqu'il est
  activé sur le domaine officiel, vérifie les objets téléchargés et conserve
  l'accès à l'ancien index pendant la transition.
- Le langage accepte les expressions `match` avec valeurs, les motifs
  littéraux scalaires et les opérateurs arithmétiques définis par l'auteur.
- La complétion LSP couvre davantage d'expressions incomplètes, de membres
  hérités et de changements dans le workspace.
- Sur les hôtes macOS ARM64 qualifiés, LLVM devient le backend par défaut ;
  les autres plateformes conservent le backend natif par défaut. Les chemins
  natifs ARM64 et X64 reçoivent aussi des corrections et optimisations.

### Impact et migration

Le registre Cloudflare doit être actif sur `registry.silex-lang.org` pour
recevoir `silex publish`. Avant la bascule, `--dry-run` fonctionne hors ligne et
les installations continuent à lire l'ancien index. Après la bascule, les
anciens clients Silex ne pourront pas installer les versions conservées
uniquement sur Cloudflare : mettez le client à jour. Les packages peuvent
désormais être publiés depuis un dossier sans Git ; un lien de dépôt reste
facultatif pour les contributeurs. Aucune modification du code source existant
n'est requise pour les nouvelles constructions du langage.

## [0.44.1] - 2026-09-09

### Pourquoi mettre à jour ?

Cette version corrige plusieurs cas où des programmes valides pouvaient être
mal analysés et rend la complétion plus fiable pendant l'édition de code
incomplet.

### Changements

- La construction préserve désormais les graphes de classes héritées.
- Les diagnostics restent corrects lorsqu'un module est importé par un atome.
- La complétion LSP reconnaît de nouveau les cascades incomplètes et les
  expressions préfixées en cours de saisie.
- Les littéraux de collection reçoivent le bon contexte de type lorsqu'ils
  sont utilisés dans une valeur optionnelle.

### Impact et migration

Cette version n'introduit aucune rupture intentionnelle et ne demande aucune
modification du code source. Une recompilation suffit. La mise à jour est
recommandée aux projets qui utilisent l'héritage de classes, les imports par
atome, les collections optionnelles ou la complétion de l'éditeur.
