# Résidence partielle des paramètres ARM64 — 11 septembre 2026

Candidat : `d3ee5be` ; référence : `4e7d71b2a1d31e6cb5f3802c2f3f96657852182a`.

Chaque champ flottant prouvé d’un paramètre mixte peut résider en registre dans
une fonction sans appel. Les autres champs et les valeurs adressées conservent
leur stockage. La capture charge directement le registre flottant final.

Le témoin isolé passe de zéro à 18 résidences flottantes scalaires, plus deux
lanes déjà présentes. La frame machine reste 1664 octets ; la frame native
passe de 1680 à 1696 octets à cause des sauvegardes de registres. Les mots
chargés/stockés dans le corps passent de 51/53 à 40/42. Ces comptes statiques
incluent les différentes branches, sans pondération par leur fréquence.

Une première capture indirecte non committée augmente le nombre d’instructions
183 → 219 et régresse de 3.9 %. La capture directe retenue donne 181 instructions.
Sur 21 rotations après six échauffements, le témoin passe de 87.932 à 85.812 ms,
ratio médian apparié 0.972267 (MAD 0.00901). Mesure murale du processus sur ARM64
physique, incluant son démarrage ; elle ne prouve aucune parité X64.

## Contre-preuve du consommateur complet

Physics Preparation reste à 446.594 ms, contre 446.243 ms avant et 223.918 ms
pour Clang C17 O3 au même layout. Ratio apparié après/avant 0.998855,
intervalle 0.986082..1.005367 : aucun gain conclu. Après/Clang 1.985386,
intervalle 1.948851..1.994187 : la parité demeure rouge.

Les 32768 états à 26 champs sont identiques entre candidats ; l’écart maximal
avec l’oracle Clang est 2.7e-7, dans les tolérances existantes. Ce contrôle
n’est pas une nouvelle exécution de la référence Box2D.

Le profil enraciné en `main` montre que le noyau complet reçoit déjà une adresse
vers l’élément, et que son résultat est déjà transmis directement à la vue de
sortie. Son corps natif reste identique à 184 instructions. Le profil enraciné
au seul noyau change le contexte d’appel retenu : sa copie d’agrégat ne décrit
pas le coût du consommateur complet. Vérifier le graphe conservé depuis l’entrée
réelle avant d’attribuer un écart à une convention d’appel.

Les sondes HotBudget écrivent IR et Machine puis échouent volontairement avec
`HotFunctionNotRegistered` : elles ne sont pas des budgets admis. Aucun registre
de contrats ni seuil n’a été assoupli.

## Validation

`check test` : 45/45 étapes, 1967/1967 tests, dont les 183 tests de langage.
Le test natif observe les snapshots, champs entiers, NaN, zéro signé et largeurs
flottantes ; une preuve machine vérifie le maintien en pile des champs adressés.
La régression complète à 26 sorties passe en Debug et Release (159 observations).
Portail et robustesse : 31/31 étapes et 74/74 tests chacun, avec le corpus cumulatif,
les contrats d’erreurs/conversions et les 144 paires de robustesse.

Les scripts conservent leurs chemins d’exécution exacts ; les sources `.txt`
sont des preuves hors corpus actif. Les journaux bruts sont conservés.
