# Résidence scalaire X64 et intégrité des appels flottants ARM64

Candidat de code X64 : `cf06ca97a5ef247b96d8942f6ec020c1b4ad4fc7`.
Correctif ABI ARM64 : `559ede0956042ef98c9763886618e0f72cfcbe08`.

## Changements

La banque XMM6..15 reçoit les scalaires flottants X64. Le graphe de vivacité
et les affinités de copies sont réutilisés ; toute valeur adressée ou dont
l’intervalle rencontre une opération non prise en charge reste en pile.
Les lanes SIMD utilisent une banque distincte et gardent leurs opérandes en
pile. Les appels maintiennent en pile leurs opérandes, résultats et valeurs traversantes.
Win64 sauvegarde/restaure les 128 bits complets de chaque XMM6..15 utilisé.
Les tests d’encodage couvrent aussi les préfixes REX des registres hauts.

La régression ajoutée révèle une troncature ARM64 préexistante. Les arguments
float64 résidents et les résultats des appels directs étaient transférés en
32 bits. Le correctif `559ede0` conserve le slot ABI de 64 bits. Six exécutions
natives contrôlent -0, un NaN avec charge utile 0x123 et 1.25, dans des appels
à un et neuf arguments. Le même défaut se reproduit avant la résidence
régionale ARM64 : les observations quatre et cinq du témoin sont fausses,
puis deviennent vraies après correction. L’assembleur et l’IR sont conservés.
La sonde hors registre HotBudget termine avec HotFunctionNotRegistered : ses
artefacts servent au diagnostic, pas à l’admission d’un budget.

## Attribution machine

Les binaires avant/après ont les mêmes sorties sous Rosetta. Aucune durée
Rosetta n’est employée comme mesure Intel physique.

| Boucle identifiée | Instructions avant/après | Accès pile avant/après | Accès SSE mémoire avant/après |
| --- | ---: | ---: | ---: |
| Huit récurrences float32 | 147 / 115 | 106 / 10 | 48 / 0 |
| Flocking | 399 / 392 | 257 / 120 | 110 / 13 |

Les comptes concernent les adresses de boucles documentées dans
`x64-float-machine-counts.json`. Ils ne prédisent pas un ratio de temps.
Le témoin autonome Flocking est une copie byte-identique du source natif du
dépôt, compilée depuis la racine du groupe avec son propre manifeste de
sources sous /private/tmp ; les liens GFX absents du groupe ne sont pas
nécessaires à ce source sans dépendance. Les sources scellées portent le
suffixe `.sx.txt` pour rester hors de la composition du corpus.

## Validation et limites

Le cas ScalarFloatResidence reste dans les 49 régressions natives, avec neuf
observations vraies en Debug/Release. Il ne fait pas partie du corpus LLVM :
la conversion flottant vers entier est explicitement hors du sous-ensemble
strict de cet émetteur d’oracle. Aucun refus de LLVM ni seuil n’est masqué.
Les 27 cas LLVM antérieurs restent inchangés.

Qualification X64 sous Rosetta : 49 régressions fixes, huit générées,
64 erreurs entières et 43 conversions dans les deux modes. Émission seule :
28 ELF/PE X64 et quatre ELF/PE ARM64. Les sorties et hashes sont conservés.
Le workflow prépare la même régression Debug/Release pour Linux et Windows,
sur ARM64 et X64 ; leur exécution native est encore requise.

Des suites intermédiaires ont reçu des SIGKILL macOS intermittents. Deux
premiers runs ont chevauché le cache partagé, puis un autre cas a échoué
sans ce chevauchement. Tous les cas isolés passent. Pour Identity, le journal
système associe le refus à un fichier devenu introuvable ; les exécutables
annoncés comme conservés n’étaient plus disponibles lors de la copie.
Les journaux sont conservés et aucun réglage système n’a été changé.
Une exécution seule du portail complet passe ensuite ; un second portail
complet après la correction ABI passe 49/49 étapes, 2150/2150 tests internes
et 183 tests de langage. Les erreurs initiales du nouveau test Zig étaient
un import masquant celui du module et une largeur de compteur incorrecte.

La Part 03 reste active : Physics Preparation demeure environ 1.75 fois plus
lent que Clang sur la dernière campagne ARM64. La baseline Intel physique
au SHA 270a53c9 échoue à la parité ; le gain physique de ce nouveau candidat
reste à mesurer avec une nouvelle autorisation de publication.


Le portail cumulatif final passe 31/31 étapes et 74/74 tests d’oracle :
27 programmes du corpus, 49 régressions natives, huit scénarios générés,
64 erreurs entières, 43 conversions, 128 programmes IR et 32 programmes LLVM.
Les mesures diagnostiques de ce portail ne sont pas une qualification de gain.
La robustesse courte passe 144 paires, cinq triplets, 14 cas natifs et quatre
négatifs ; le contrat qualifié distinct conserve ses 41 cas natifs.

La robustesse qualifiée finale passe 31/31 étapes et 74/74 tests, avec
144 paires, cinq triplets, 41 cas natifs et quatre négatifs.
