# Opérandes SSE scalaires directement alloués

Le candidat `886cc17e59203c7c6b42190ddfe28239a0ece81d` évite les copies
systématiques des opérandes flottants vers XMM0/XMM1. Arithmétique scalaire et
comparaisons ordinaires/fusionnées utilisent directement leurs résidences.
Les opérandes en pile gardent les scratchs existants. Si le résultat réutilise
l’opérande droit d’une instruction destructive, le calcul passe par le scratch
avant la copie finale ; l’ordre des opérandes n’est jamais inversé. Min/max
et les opérations SIMD conservent leur abaissement.

Compilateur local SHA-256 :
`f873bbef7d51cacd55a709669cf11704ffbe43ec15b9c91e20b4eaf43f54e962`.
Référence : `7bd153ce94975ccc2143679a85ef99fd1fa0db4f`.

Les deux tests ciblés passent. La mutation rétablissant l’ancienne arithmétique
échoue sur le témoin structurel. LLVM MC confirme indépendamment les octets
pour les registres hauts et l’alias droit. Le portail passe 49/49 étapes,
2160 tests internes et 183 tests de langage. L’oracle passe 31/31 étapes,
74 tests, 54 cas fixes, huit générés, 64 erreurs entières et 43 conversions.
La qualification X64 locale sous Rosetta passe aussi ces 54/8/64/43 cas.
Robustesse : 144 paires, cinq triplets, 41 natifs, quatre négatifs et stress
cache/graphe verts.

Le témoin donne 18 lignes `true` en Debug/Release sur macOS ARM64 et X64.
Douze émissions couvrent les six cibles. Son désassemblage Release contient
bien soustractions, divisions, additions, multiplications et comparaisons
float32/float64 : les assertions ne sont pas toutes pré-calculées.
Les trois charges ARM64 et Arithmetic/Objects X64 restent identiques à la
référence. Dans `steer`, le comptage statique passe de 425 à 355 instructions
et de 108 à 38 copies flottantes. Les 166 accès pile restent identiques.
Ces comptes ne remplacent pas une mesure temporelle physique.

La [matrice native](https://github.com/Matanek/Silex/actions/runs/34653738617)
est en cours sur ce SHA exact. Aucun gain Intel physique n’est encore
revendiqué pour ce candidat. La campagne de `7bd153c` continue indépendamment
avant le lancement de la suivante. La Part 03 demeure active.

`manifest.json` scelle les preuves locales, les désassemblages, les encodages
LLVM de référence et les exécutables, hors manifest lui-même.
