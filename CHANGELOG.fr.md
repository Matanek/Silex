# Journal des versions de Silex

Ce journal aide à décider s'il faut mettre Silex à jour et à préparer les
adaptations nécessaires. Chaque candidat de release ajoute d'abord son entrée
française, puis sa traduction anglaise dans `CHANGELOG.md`. Les changements en
cours sont consignés sous `## [Unreleased]`, puis regroupés lors de la release.
Cet historique éditorial commence à la version 0.44.1.

## [Unreleased]

- Les appels génériques contraints conservent le contrat public du protocole avec un conformant local ou de package, y compris depuis un champ de type générique. Les autres surcharges et membres restent masqués ; la complétion suit la contrainte des champs génériques et leurs retours.

- L’inférence de mutabilité reconnaît les écritures de `self` dans les branches `try … else` ; les emprunts modifiables y fonctionnent et les getters conservent leur diagnostic de mutation.

- Les variantes d’un enum principal restent des valeurs lorsque son module contient des fonctions homonymes ; les références de callbacks distinctes restent disponibles.

- LLVM Debug évite `opt` pour les unités dont les fonctions émises ont uniquement des sauts vers l’avant, sans annotation spéciale. Les boucles et formes inconnues gardent le pipeline O0 existant ; `llc` vérifie toujours ses entrées. Le compteur de trace `llvm_units_optimized` expose les unités confiées à `opt`, et la politique participe à leur identité de cache. Release garde son pipeline O3 et son découpage. Sur le corpus local macOS ARM64, la compilation LLVM Debug de Boids baisse de 23,9 % et celle du Tokenizer de 23,7 %, avec exécutables identiques ; protocole et limites dans `Docs/LLVM-debug-preparation.md`.

- Une chaîne lue par un emprunt `@` ou `&` peut être passée par valeur ou conservée dans un champ possédé, comme lors d’un retour ordinaire. Sa mémoire immuable reste retenue ; l’emprunt et les références de classe ne peuvent toujours pas s’échapper.

- Le backend LLVM accepte les signatures fixes de `objc_msgSend` dont les handles sont représentés par des mots de 64 bits, en conservant les contrôles de fournisseur et de signature C. Ses temporaires de texte sont libérés avant les outils LLVM : Boids compile désormais en Debug et Release sur macOS ARM64, sous la garde mémoire locale. Le natif conserve son comportement.

- Le frontend indexe une fois les déclarations source pour les recherches d’héritage et de protocoles. Il consulte le nom interne courant, y compris après inférence des tuples, et reconstruit cet index à chaque analyse. Le mécanisme est commun aux deux backends et aux six cibles ; les preuves et limites sont dans `Docs/Frontend-lookups.md`.

- La recherche des conflits de registres utilise des masques de vivacité et de définition par slot pour éviter les balayages répétés des points morts. Le graphe ARM64 partagé avec les scalaires flottants X64 conserve les mêmes règles de partage et décisions ; les tables temporaires sont libérées après chaque graphe. Mesures locales macOS ARM64 : compilation de Boids réduite de 7,1 % en Debug et de 52,3 % en Release face à la tranche précédente, avec exécutables identiques ; protocole et limites dans `Docs/Native-conflicts.md`.

- Le solveur de vivacité natif calcule les usages et définitions une seule fois, puis résout le point fixe par mots de 64 bits. Il conserve la même matrice booléenne pour les allocateurs de registres ARM64 et leurs consommateurs X64 ; ses tables temporaires sont libérées à chaque résolution.

- Les vérifications de chaque passe d’optimisation libèrent leurs temporaires avant la passe suivante. La validation partage les contrôles du texte IR et réutilise son stockage par fonction. Le mode Debug conserve tous ses contrôles sans accumuler leur mémoire dans le résultat de compilation.

- Le lanceur natif de tests libère les temporaires d’émission et de liaison après chaque scénario, au lieu de les conserver jusqu’à la fin du fichier. Le programme commun, les sorties capturées, les diagnostics et la conservation des artefacts en cas de signal gardent leur contrat.

- Les callbacks C disposent d’une entrée native distincte : arguments et résultats flottants, registres préservés et arguments sur pile suivent l’ABI de la cible, y compris après réduction du programme aux fonctions utilisées. `C.call` et les callbacks acceptent des paramètres records plats de champs 64 bits ; leurs résultats restent scalaires. Les liaisons C acceptent aussi `uint16`. Les références doivent être résolues sans capture à la compilation, directement ou par alias immuable. Les références de méthodes statiques peuvent être inférées sans annotation ; une déclaration locale garde priorité sur un homonyme de namespace. La complétion insère ces références sans appel et retrouve le contexte des arguments C indirects.

- Les littéraux de collection utilisés comme remplacement optionnel héritent du type de la valeur, y compris les listes vides et les champs de tuples ; l’élargissement des remplacements numériques est préservé. La complétion conserve le même contexte d’élément.

- Les lectures d’entiers signés étroits après une écriture par pointeur C rétablissent correctement leur signe, y compris dans les champs, emprunts et éléments de collection.

- Les appels via un protocole conservent le récepteur de classe pendant les arguments et callbacks, puis gardent son identité partagée sans réécrire le champ d’origine. Un remplacement réentrant reste en place, tandis que les conformités de type valeur conservent leur mise à jour. Les appels sûrs depuis un champ optionnel participent à l’inférence de mutabilité.

- La collecte native réutilise les offsets et types des champs pendant un parcours, dans une réserve bornée au contexte existant ; les agrégats sans référence de classe évitent leurs visites répétées. La saturation conserve le parcours complet. Les valeurs, racines et finaliseurs restent inchangés. Implémentation partagée par les payloads ARM64/X64 ; mesures CPU limitées à leurs configurations macOS ARM64 Debug, sans gain global ni exécution des autres systèmes revendiqués.

- Les méthodes de protocole peuvent fournir un corps par défaut : les conformants existants le réutilisent, une implémentation explicite garde priorité, et les appels concrets, génériques et dynamiques conservent le même choix. Les corps sont vérifiés dans la portée du protocole, même inutilisés ; les défauts concurrents exigent une résolution explicite. La complétion, les labels et la navigation suivent les déclarations d’origine, y compris avec imports et extensions.
- Les appels de méthodes à travers un protocole acceptent les arguments nommés selon les labels du protocole. Comparer un protocole optionnel au littéral `null` vérifie sa présence sans exiger que son contenu soit comparable.
- `main` conserve la portée de son module pour les appels entre atomes. Le LSP indexe aussi les fichiers ouverts avant leur premier enregistrement, en conservant leur identité de fichier ou d’atome et leurs limites de visibilité.
- Le Debug natif prépare les valeurs et place les temporaires en registres, avec intégration bornée des petits helpers sans branchement. Les contrôles et informations source restent disponibles ; les helpers intégrés ne créent plus d’entrée séparée dans la pile d’appels. Le lanceur de tests emploie la même politique. Le monster truck conserve ses quatre pneus souples et ses paramètres physiques ; voir la qualification locale et ses limites dans `Docs/Debug-preparation.md`.

- Le Debug natif élimine les copies temporaires inutilisées et évite les transferts scalaires redondants sur la pile, tout en conservant appels, positions source, contrôles et ownership. Le solveur du pneu souple conserve ses paramètres et ses observations physiques ; qualification locale macOS ARM64, sans gain généralisé aux autres cibles. Voir `Docs/Debug-copy-cleanup.md`.

- `match` libère aussi le sujet temporaire qui contient des ressources lorsqu’il sélectionne `else`. Les branches avec liaison de payload conservent leur transfert, et un sujet emprunté reste vivant ; tests de destruction des objets en natif et contrôle LLVM.

- Ajout de `round_float<T>(value)` : conversion flottante avec arrondi explicite vers `float32` ou `float64`, au plus proche avec égalités au pair, sous-normaux, zéro signé, infinis et NaN. La conversion `as` conserve son contrôle sans perte.

- Les lanceurs de tests LSP et d’admission reçoivent la même pile Debug de 32 Mio que le bootstrap : le test de récursion atteint son diagnostic au lieu de déborder la pile système.

- La collecte native des cycles ignore aussi les champs scalaires, chaînes et optionnels scalaires, tout en conservant leur largeur réservée. Les parcours fréquents d’interface évitent ces visites sans masquer les références de classes ni les callbacks. Régressions du collecteur et des cycles natifs ; mesures locales de la galerie de tableaux.
- Les valeurs par défaut de paramètres conservent les droits de leur déclaration : les enums et helpers internes restent utilisables dans les fonctions, constructeurs et méthodes, sans donner ces droits à l’appelant.

- Un alias de fonction importée ne renomme plus une méthode homonyme appelée sur un récepteur ; appels d’instance, statiques, génériques et de protocole conservent leur résolution propre.

- Une opération `Result<T,E>` possède une seule implémentation : l’appel ordinaire produit `T` ou panique ; `try operation()` conserve le `Result`. Cette évolution remplace l’ancienne extraction/propagation de `try`. Les propagations utilisent désormais une branche explicite `else error { return … }`, et les anciennes captures ordinaires ajoutent `try`. Les constructions explicites de Result restent des données ; receveur, arguments et défauts gardent une évaluation unique. Le LSP suit le mode d’appel et les caches antérieurs sont invalidés.

- Les fonctions anonymes conservent les droits privés/protégés de leur contexte lexical, y compris après imbrication et pour les méthodes statiques. Capturer un récepteur depuis l’extérieur ne donne aucun accès supplémentaire ; les restrictions des extensions restent appliquées.

- Les structures récursives via des listes dynamiques se copient et se détruisent sans récursion infinie du compilateur ; leurs opérations de ressources utilisent des appels IR, comme les protocoles récursifs. Régressions interprétées et natives macOS ARM64.
- Accepter append(null) pour une liste d’éléments optionnels en utilisant le type connu du récepteur, sans modifier l’ajout de séquences.

- Les parenthèses peuvent regrouper un type : `(func(str) int?)?` distingue une fonction optionnelle de son résultat optionnel. Les callbacks optionnels génériques conservent leur signature et les suggestions de types restent disponibles dans ces annotations.

- Un callback stocké dans un champ d’élément de tableau peut être appelé directement, y compris depuis une collection détenue dans un champ. Le récepteur et l’index sont évalués une seule fois ; complétion et durée de vie du récepteur lié sont couvertes.

- Le collecteur de cycles natif ignore aussi les tableaux de structures et d’énumérations composées uniquement de scalaires, chaînes et collections sans référence de classe. Les grandes sources de `Select` ne sont plus parcourues à chaque nettoyage temporaire ; les arêtes de classes et callbacks et les finalizers ordinaires restent préservés. Régressions et mesures natives macOS ARM64 ; les payloads communs ARM64/X64 sont reconstruits, sans nouvelle preuve d’exécution sur les autres hôtes.

- Conserve le contexte commun des arguments nommés de fonctions et méthodes statiques surchargées : listes de structures/protocoles et listes vides utilisent le type partagé des paramètres, sans tableau intermédiaire ni choix arbitraire lorsque les types diffèrent.

- Les gardes d’erreur ARM64 atteignent leur handler au-delà de 1 Mo, notamment dans les grands constructeurs composés. Le chemin normal et la propagation des erreurs conservent leurs résultats ; régressions d’encodage Darwin/Linux/Windows et exécution native macOS, sans nouvelle preuve d’exécution Linux/Windows.
- Compose la conversion numérique implicite avec la promotion optionnelle : durées `float` vers `float64?`, sans extraction ni rétrécissement implicite ; coût des surcharges et propositions du LSP cohérents. Les arguments nommés de méthodes surchargées transmettent le type attendu commun aux listes sans sélectionner arbitrairement une surcharge.

- Réutiliser l’identité des tableaux de types génériques déjà déclarés dans la source pendant leur spécialisation. Une méthode retournant `Option<Choix>[]` et un champ `Option<T>[]` ne déclarent plus deux structures portant le même nom.

- Le collecteur de cycles natif ignore les éléments des tableaux de scalaires, chaînes et scalaires optionnels : ils ne portent aucune arête de classe. Les données d’une grande liste ne sont plus parcourues à chaque nettoyage temporaire ; les tableaux contenant des classes restent tracés.

- Le parseur distingue les comparaisons composées des appels génériques lorsque l’un des opérandes est parenthésé ; les arguments de types avec tableaux fixes, tuples et fonctions restent reconnus.

- Sur X64, `append()` réutilise la capacité disponible d’une liste non partagée et réserve de l’espace lors de sa croissance. La construction de grands tableaux ne recopie plus tout leur contenu à chaque ajout ; les snapshots partagés restent indépendants.

- Une itération mutable `indexed()` conserve l’élément possédé jusqu’à sa réécriture. Le nettoyage du corps tenait compte de l’élément mais oubliait la liaison d’index, provoquant une libération prématurée et un crash X64.

- `for var` et `indexed()` peuvent parcourir un champ de collection modifiable en réécrivant son stockage à chaque itération, y compris avant continue et break ; les copies de listes restent indépendantes.

- L’inférence de mutabilité suit aussi les vues modifiables de champs, les méthodes des protocoles contenus et les itérations modifiables sur les collections de self. Les getters restent protégés contre ces mutations indirectes.

- Les propriétés de protocole se lisent depuis les paramètres de constructeur et les éléments empruntés d’une collection sans exiger un récepteur modifiable ni réécrire son stockage.

- En Release ARM64, une boucle testant `value % 2 == 0` ou `!= 0` réévalue correctement la parité après chaque tour. Les boucles imbriquées ne lisent plus un reste éliminé par la fusion des instructions.

- Sur ARM64, le nettoyage des références de classe adresse son contexte runtime indépendamment des registres de valeurs lorsque la pile atteint la limite de 32 Kio. Cela évite un crash ou la corruption d’un registre vivant à cette limite, notamment lors de la construction de descriptions UI en Release.
- Les tranches modifiables `&T[..]` traversent les méthodes, constructeurs et callbacks comme les fonctions libres, y compris les appels nommés et les protocoles dynamiques.

- Une cascade sur une valeur temporaire passée à un paramètre optionnel modifie désormais la valeur avant son injection dans l’optionnel, y compris pour les classes et collections. La complétion conserve les membres du récepteur concret.

- `publish --dry-run` et la préparation de publication utilisent Shadercross configuré par `silex setup`, comme les autres commandes de compilation. Les packages dont une source importe des programmes HLSL ne sont plus refusés à tort comme non configurés.

- `take_last()` réutilise le buffer d’une collection non partagée sur ARM64 et X64, au lieu de recopier tous ses éléments. Les snapshots partagés, les formats float32 et les ressources extraites conservent leur propriété.

- Les références de fonctions visibles dans un module restent accessibles depuis les constructeurs et méthodes de ses autres atomes, avec les mêmes règles de visibilité que les appels. La complétion conserve la signature d’un champ callback et propose les fonctions de ses autres atomes ; la navigation retrouve leur déclaration canonique. Les fonctions locales au fichier et les modules privés restent inaccessibles hors de leur portée.

- Les descriptions récursives transportées dans des collections de valeurs de protocole conservent et libèrent désormais leurs contenus sans récursion infinie du compilateur. Un cycle directement imbriqué par valeur est diagnostiqué : sa représentation doit passer par un champ de classe ou de tableau dynamique.

- Les appels génériques dans un callback anonyme infèrent désormais leurs types depuis les valeurs capturées, y compris dans les callbacks imbriqués et les fonctions parentes génériques. Les paramètres du callback conservent leur masquage lexical ; les règles de durée de vie des captures restent inchangées.

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
