# Journal des versions de Silex

Ce journal aide à décider s'il faut mettre Silex à jour et à préparer les
adaptations nécessaires. Chaque candidat de release ajoute d'abord son entrée
française, puis sa traduction anglaise dans `CHANGELOG.md`. Les changements en
cours sont consignés sous `## [Unreleased]`, puis regroupés lors de la release.
Cet historique éditorial commence à la version 0.44.1.

## [Unreleased]

- `take_last()` réutilise le buffer d’une collection non partagée sur ARM64 et X64, au lieu de recopier tous ses éléments. Les snapshots partagés, les formats float32 et les ressources extraites conservent leur propriété.

- Les références de fonctions visibles dans un module restent accessibles depuis les constructeurs et méthodes de ses autres atomes, avec les mêmes règles de visibilité que les appels. La complétion conserve la signature d’un champ callback et propose les fonctions de ses autres atomes ; la navigation retrouve leur déclaration canonique. Les fonctions locales au fichier et les modules privés restent inaccessibles hors de leur portée.

- Native Release ARM64 conserve les constantes flottantes utilisées avant la définition de leur partenaire SIMD ; les rotations de quaternion ne lisent plus une ancienne valeur de registre dans ce cas.

- Le remplacement d’un champ possédant une ressource dans un élément de collection de classe ne libère plus deux fois l’ancienne référence. Les snapshots partagés restaurés et les auto-affectations conservent leur ressource jusqu’à la destruction du dernier propriétaire.

- Les méthodes d’extension `module` sont accessibles depuis les atomes et enfants d’implémentation du module fournisseur activé, y compris les appels statiques, nommés et génériques. La complétion et la navigation LSP suivent les imports directs et transitifs du fichier en cours d’édition et retrouvent l’atome déclarant. Les méthodes `module` restent masquées hors de ce module, les méthodes `local` hors de leur fichier.

- Les types `package` importés depuis un module composé sont résolus dans leur atome déclarant, indépendamment de l’ordre des fichiers. Le LSP conserve les imports canoniques `Package`, leurs aliases, les membres et variantes autorisés ; les types locaux et les types privés au package restent masqués aux consommateurs extérieurs.

- Dans un constructeur explicite, un champ de classe sans expression `=` attend désormais la référence qui lui est affectée, même si sa classe possède un constructeur sans argument. Il ne crée plus d’instance temporaire immédiatement remplacée ; une construction préalable souhaitée doit être écrite sur le champ avec `= Resource()`. Les lectures prématurées et chemins sans initialisation sont diagnostiqués.

- Les constructeurs surchargés transmettent un type attendu à un argument lorsque tous les candidats visibles acceptant l’appel partagent ce type de paramètre ; les listes vides ou de dimensions calculées peuvent ainsi être écrites directement sans choisir arbitrairement une surcharge. La complétion propose le type de l’élément à l’intérieur des listes et conserve les appels nommés, imbriqués et incomplets.

- Un helper abstrait inutilisé peut déclarer des appels de protocole sans imposer une implémentation concrète au programme ; son corps reste vérifié et aucun conformer artificiel n’est ajouté.

- Les appels dynamiques de protocole retiennent leurs arguments possédés et transfèrent leurs résultats comme les appels ordinaires ; le calcul natif ne libère plus les listes encore utilisées par l’appelant.

- Les dépendances réciproques entre un module et son descendant sont acceptées dans la hiérarchie d’un même package ; les branches étrangères restent refusées.
- Les champs de visibilité `module` d’une classe avec destructeur restent accessibles entre les atomes de son module composé, sans exposer ses champs privés.

- Corriger `interpret` pour accepter `list.insert(list.count(), value)`,
  y compris sur une liste vide, sans élargir les bornes de lecture ou de retrait.

- Les méthodes statiques propagent désormais `try` selon leur retour `Result`, y compris les résultats sans valeur et les messages d’erreur ; les alternatives locales restent disponibles.
- `interpret` ignore les fonctions système importées qui ne sont pas atteignables
  depuis `main`. Les appels effectifs et callbacks pouvant atteindre une frontière
  non prise en charge restent refusés ; les programmes purement portables d’un
  module proposant aussi des entrées fichiers peuvent être comparés au natif.

- Les systèmes injectés sélectionnent leur fonction selon la visibilité du
  module appelant. Une fonction homonyme privée chargée depuis un autre module
  ne provoque plus un faux refus de callback ; aucun nom source à contourner.

- `try`, y compris ses alternatives locales et messages, conserve le retour `Result` et l’état du récepteur dans les méthodes modifiables de structures et classes. Les erreurs propagées ne contournent plus le retour du récepteur.

- La vérification de visibilité d’une liste partagée entre atomes de source
  suit le type d’élément dans son atome déclarant. Un type privé sans rapport
  dans l’atome appelant ne provoque plus de faux rejet d’une signature package
  ou publique ; les véritables fuites de types privés restent rejetées.

- Native ARM64 Release charge correctement les lanes SIMD d’un vecteur
  flottant lu dans une liste à stockage large. Emprunter un autre élément de
  cette liste ne change plus les coordonnées calculées ; la construction d’un
  coin convexe dans une scène graphique est qualifiée sur macOS ARM64.
  Émission ARM64 Darwin/Linux/Windows couverte ; ces deux derniers systèmes
  ne sont pas exécutés dans cette validation locale.

- Native ARM64 conserve les bits lors des copies scalaires ou des champs
  d'agrégats entre registres généraux et flottants. `abs` d'un champ en Release
  ne relit plus un emplacement mémoire périmé. Les intrinsics `copysign` et
  `sqrt` lisent et écrivent aussi la voie float32 appariée correcte sans
  écraser la composante voisine.

- Les calculs SIMD différés conservent leurs opérandes jusqu’à leur émission
  réelle. En Native ARM64 Release, un chargement scalaire intermédiaire ne
  peut plus écraser une composante : les distances et cadences de déplacement
  retrouvent les résultats de LLVM. Les grands indices de copies agrégées
  évitent aussi un dépassement intermédiaire dans la toolchain Debug.

- Native ARM64 conserve les copies de composantes flottantes dont la copie
  SIMD partenaire a été supprimée comme inutilisée. Les affectations partielles
  de vecteurs ne provoquent plus `InvalidMachineProgram` à l’émission Release.

- Correction Native Release : les affinités vectorielles de `min/max` restent
  scalaires tant que leur opérateur ne possède pas d’émission SIMD compatible.
  Cela corrige notamment les projections d’ombres déformées dans les scènes 3D.

- Correction Native ARM64 Release : les feuilles chargées ensemble depuis
  un champ agrégé de classe conservent des registres distincts. Une feuille
  inutilisée ne peut plus écraser l'identifiant ou la valeur encore utilisée.

- En Native ARM64 Release, les fonctions qui appellent une bibliothèque
  externe attendent la résolution de ses signatures avant l’allocation des
  registres. Les intrinsics mathématiques évitent ainsi les transferts de pile
  imposés auparavant par un appel encore inconnu.

- Le backend Native ARM64 conserve les valeurs numériques indépendantes en
  registres autour des opérations de classes. Leurs allocations et libérations
  utilisent directement l’ABI système sur macOS et Windows, sans sauvegarder
  systématiquement tous les registres temporaires.

- En Native ARM64 Release, les calculs réutilisent directement les valeurs des
  copies temporaires sur la pile lorsque leur stockage reste inchangé. Les
  adresses exposées et les frontières de contrôle conservent leurs copies.

- En Native ARM64 Release, les chargements de structures mixtes protègent
  leurs résultats en mémoire sans désactiver les registres de toute la
  fonction. Les régions de calcul sont admises dès 16 opérations flottantes.

- En Native ARM64 Release, les chaînes de copies de structures ne transfèrent
  plus leurs champs inutilisés. Les stockages accessibles par adresse et les
  transferts qui se chevauchent restent intégralement préservés.

- En Native ARM64 Release, un appel recevant une structure dans une boucle
  ne force plus toute la fonction à utiliser la pile. Les arguments et
  résultats agrégés restent protégés en mémoire ; les calculs indépendants
  peuvent conserver leurs registres.

- En Native ARM64 Release, les lectures et écritures de champs de classes
  peuvent utiliser directement les registres scalaires, ce qui évite des
  copies intermédiaires sur la pile. Les champs mixtes conservent leurs bits
  et les registres SIMD compactés restent exclus de ces transferts.

- L’allocation de registres tient compte de tous les paramètres capturés à
  l’entrée, même inutilisés. Un paramètre inutilisé ne peut plus écraser le
  registre d’un argument encore vivant dans le prologue natif.

- Sur macOS ARM64, les compteurs de références des classes utilisent les
  instructions atomiques LSE garanties par Apple Silicon. La décrémentation
  reste saturante et conserve la synchronisation acquire/release ; les autres
  cibles gardent leur chemin existant.

- Les chaînes natives ARM64 issues d’une concaténation, d’octets ou d’un
  formatage réservent et écrivent explicitement leur zéro terminal. Le
  formatage X64 fait de même. Les appels C recevant une chaîne construite
  n’accèdent plus à l’octet suivant l’allocation, ce qui corrige notamment
  les titres de fenêtre invalides ; la longueur logique reste inchangée.

- Les listes natives ARM64 sur macOS et Windows réservent initialement
  128 octets au lieu d’une page entière. Leur croissance reste géométrique,
  avec les mêmes garanties de copie, de détachement et de destruction ;
  les petites collections évitent ainsi la mise à zéro de pages inutilisées.

- Le mode Release élimine les paires de références temporaires autour des
  lecteurs prouvés et des écritures de valeurs numériques. Sur ARM64 macOS
  et Linux, les transferts de champs de classes préservent les registres
  arithmétiques et les continuations inline ne sont plus prises pour des
  boucles. Les barrières d’ownership et les vrais cycles restent protégés.

- Correction en Native Release ARM64 de l'association SIMD de deux champs
  flottants produits par des opérations différentes, par exemple les bornes
  `centre - rayon` et `centre + rayon`. Une régression native vérifie les deux
  valeurs en Debug et Release ; le défaut produisait deux fois la borne basse.
- Le cache des méthodes de packages suit désormais les shaders, leurs fichiers inclus et les fichiers embarqués. Modifier ou supprimer un de ces fichiers invalide les constantes compilées correspondantes ; les compilations suivantes conservent ces dépendances, même après plusieurs réutilisations du cache.
- Correction d’un crash Release natif lors du parcours d’une liste dans un enum dont une autre variante contient des flottants. L’inférence des registres flottants respecte désormais la frontière entre le stockage partagé de l’enum et ses charges typées ; une régression autonome couvre ce cas.
- Correction d’une normale erronée en Native Release ARM64 lorsque des copies conditionnelles faisaient partager un registre SIMD à deux paires flottantes encore vivantes. Le coloriage conserve ces paires distinctes tant que leurs durées de vie se recouvrent ; une régression de géométrie 3D contrôle la normale et la séparation.

## [0.47.1] - 2026-09-25

### Pourquoi mettre à jour ?

Cette version réduit le coût des petites allocations des programmes natifs
Windows, sur ARM64 comme sur x64. Le backend par défaut reste `native` sur les
six plateformes ; le contrat du langage et de l'ownership ne change pas.

### Changements

- Le backend natif Windows ARM64 et x64 utilise le tas système pour les chaînes,
  collections, classes et callbacks de copie/collecte, au lieu d'une réservation
  de mémoire virtuelle par allocation. Les adaptateurs préservent les registres
  temporaires et SIMD ; le contrat de valeurs et d'ownership ne change pas.
- La qualification des distributions vérifie désormais les allocations,
  les copies et les cycles, puis une charge fixe en Debug et Release, sur
  chaque cible native. Les mesures restent séparées des tests de correction.
- Les notes historiques de 0.47.0 distinguent les changements communs, les
  mécanismes propres aux cibles et la portée réelle des mesures.

Le [diagnostic à travail fixe](https://github.com/Matanek/Silex/blob/v0.47.1/Toolchain/Benchmarks/Native/Allocation/README.md)
compare le candidat Windows à 0.47.0 sur le même hôte, avec douze mesures Release
par configuration : médiane de 146,25 à 11,69 ms sur x64 et de 178,10 à 14,94 ms
sur ARM64. Ces résultats incluent le démarrage du processus et ne prédisent pas
le gain d'une application. Linux et macOS x64 conservent leurs chemins
d'allocation existants ; leur extension reste à faire et aucun gain n'y est annoncé.

### Impact et migration

Recompilez les programmes Windows pour bénéficier du nouvel allocateur.
Aucune migration de source ni changement de backend n'est nécessaire.

## [0.47.0] - 2026-09-24

### Pourquoi mettre à jour ?

Cette version unifie le choix du backend par défaut : `native` sur les six
plateformes distribuées. Elle réduit des copies dans l'optimiseur commun et
corrige des erreurs de durée de vie et de génération de code. Des améliorations
supplémentaires concernent certaines architectures et certains backends, comme
précisé ci-dessous.

### Changements

#### Comportement et traitement communs

- `run`, `test` et `compile` sans `--backend` choisissent `native` sur macOS,
  Linux et Windows, en ARM64 comme en x64.
- L'optimiseur commun réduit les copies d'agrégats imbriqués. Cette
  transformation intervient avant la génération propre à chaque cible.
- Les deux backends renforcent la collecte des cycles et la préservation des
  descendants encore vivants.
- Le compilateur libère plus tôt les données d'analyse devenues inutiles et
  borne la mémoire temporaire de certaines analyses et évaluations.

#### Changements propres à une cible ou à un backend

- La génération native ARM64 admet davantage de régions scalaires et optimise
  des noyaux à vues vérifiées. Elle préserve correctement les registres SIMD et
  les composantes flottantes lors des appels.
- L'allocateur natif de macOS ARM64 utilise le tas système (`calloc`/`free`)
  plutôt qu'un mapping mémoire par petite allocation. Les chemins d'allocation
  des cinq autres cibles ne changent pas dans cette version.
- LLVM corrige la copie des graphes de classes récursifs, l'égalité des enums
  à données, les appels hérités, les ressources, les collections et callbacks.
  Ce backend reste disponible explicitement sur macOS ARM64 avec `--backend llvm`.

#### Mesure de performance disponible

Le [diagnostic CCD à travail fixe](https://github.com/Matanek/Silex-Lib-GFX.Physics/blob/c9f85526488f0dbed0842a22ca484d06b1f46772/Benchmarks/Baselines/2026-09-24-native-heap.md)
compare l'allocateur avant et après sa modification, en natif Release sur
macOS ARM64 : 16 corps, quatre parois mobiles et 24 pas. Les deux paires de
mesures passent de 16,48–17,06 à 1,70–2,51 ms/pas, à code physique et états
finaux identiques. Elles isolent ce coût ; elles ne mesurent ni le gain complet
entre versions publiées ni les autres cibles, et ne garantissent pas les FPS
d'une application.

### Impact et migration

Sur macOS ARM64, ajoutez `--backend llvm` si vous souhaitez conserver le backend
par défaut de 0.45–0.46. Ailleurs, le choix par défaut ne change pas. Recompilez
vos programmes pour bénéficier des corrections ; aucune migration syntaxique
n'est requise.

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
