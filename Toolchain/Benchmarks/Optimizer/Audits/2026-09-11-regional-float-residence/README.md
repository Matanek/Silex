# Résidence flottante entre appels — 11 septembre 2026

Candidat : `0ba0b85ab1dc7d69ea4d13a10ad5815aa74a7688` ; référence : `0ea7c34`.

Les valeurs scalaires peuvent utiliser les registres flottants volatils ARM64
lorsqu’elles ne rencontrent aucun appel dans le graphe de vivacité. Toute
composante coalescée contenant un opérande, un résultat ou une valeur vivante
à un appel conserve les restrictions d’ABI. Les lanes SIMD gardent leur
politique précédente, ainsi que les valeurs adressées et les barrières.

## Preuve causale

Un témoin de huit récurrences flottantes après un appel réel perd les 32
chargements et 32 stockages de sa boucle. Celle-ci passe de 130 à 66 instructions ;
la frame native passe de 688 à 656 octets. Sorties avant/après identiques :
`3000000` puis `35.999138`.

21 paires alternées après six échauffements : 30.612 → 9.113 ms. Ratio apparié
0.294432, intervalle 0.289782..0.297823, MAD 0.006123, déplacement entre
moitiés de fenêtre 1.20 %. Mesure murale incluant le démarrage sur ARM64 physique ;
environ 3.4× plus rapide sur ce témoin, sans prétention de parité X64.

Physics Preparation ne gagne pas : 441.459 → 443.094 ms, Clang 253.535 ms.
Ratio après/avant 1.003704, intervalle 0.998845..1.006493 ; après/Clang
1.747743, intervalle 1.740474..1.755146. Les 32768 états à 26 champs restent
exactement identiques. Le noyau demeure à 147 instructions ; l’appelant perd
22 chargements et 22 stockages statiques, ce qui ne prouve pas un gain dans la
zone chronométrée. Les valeurs traversant le chemin d’affichage restent un
problème différent des temporaires entre appels.

## Validation

`check test install` : 49/49 étapes, 2147/2147 tests, 183 tests de langage.
Portail cumulatif et robustesse : 31/31 étapes, 74/74 tests chacun ; 144 paires,
cinq triplets, 41 cas natifs et quatre négatifs. Un test machine distingue les
temporaires des valeurs présentes à l’appel. Un test natif fait écraser tous
les registres FP allouables par le callee et vérifie la valeur du caller.
Le contrôle des appels mathématiques en float32/float64 et petites/grandes
frames vérifie toujours les registres conservés au point d’appel.

Les échecs intermédiaires étaient des erreurs de tests : assertion ancienne
imposant les registres conservés à toute la fonction, assertion nouvelle trop
stricte sur une composante coalescée, et largeur de retour omise dans le test
natif. Aucune modification supplémentaire de la politique n’a été nécessaire.
Les sources et états de référence complets sont scellés dans l’audit voisin
`2026-09-11-dominated-reference-reads`. Aucun seuil de benchmark n’a été changé.
