# Journal des versions de Silex

Ce journal aide à décider s'il faut mettre Silex à jour et à préparer les
adaptations nécessaires. Chaque candidat de release ajoute d'abord son entrée
française, puis sa traduction anglaise dans `CHANGELOG.md`.

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
