# Conversions numériques exactes — 11 septembre 2026

Candidat : `211feb934f7caf969bdf3286b707daccbb760578` ; référence des reproductions :
`5d15ebe73626d73d2faa476ad1a481e1226f00c4`.

X64 ignorait les contrôles de conversion : plages, fractions, précision,
réinterprétation signée des grands non-signés. ARM64 acceptait une valeur
arrondie à la borne supérieure lorsque sa reconversion saturait sur l’entier
initial. L’interpréteur et les constantes statiques comparaient des entiers
convertis en `float32` via une valeur `float64` déjà arrondie.

Les contrôles comparent désormais à l’entier exact, rejettent les bornes
supérieures exclusives et conservent le diagnostic avec sa position. X64
emploie XMM3–XMM5, réservés par l’allocation de lanes sur les deux ABI ; ses
conversions non signées de 64 bits traitent explicitement le bit supérieur.

## Preuves

- 60 exécutions de référence et 60 corrigées ; après correction, codes,
  valeurs et diagnostics ARM64/X64 identiques pour les 15 sondes.
- 43 contrats permanents, 172 exécutions Debug/Release rescannées et hashées
  ici : largeurs, limites, pertes de précision, fractions, NaN, infini,
  zéro négatif et grands non-signés exactement représentables.
- Contre-preuve statique : l’ancien compilateur accepte `max(uint64)` vers
  `float32`, le candidat le rejette ; `2^63` demeure accepté.
- `check test install` : 49/49 étapes, 2142/2142 tests ; 183 tests de langage.
  Les tests d’octets de conversion conservent leur contrôle de l’opération
  et ciblent maintenant les registres temporaires réservés.
- Portail : 31/31 étapes, 74/74 tests, corpus cumulatif, 128 programmes
  différentiels et 32 LLVM. Les deux architectures passent les 47 régressions,
  huit scénarios générés, 64 erreurs entières et 43 conversions.
- Robustesse : 144 paires, cinq triplets, 41 cas natifs, quatre négatifs.
- 56 émissions ELF/PE, sans exécution Linux/Windows.

ARM64 est physique ; X64 s’exécute sous Rosetta. Aucun résultat temporel de ces
portails n’est utilisé comme preuve de performance, car des compilations et
qualifications se chevauchaient. Les diagnostics des contrats portent le chemin
local de leur source ; chaque qualification les compare à l’interpréteur sur
ce même chemin. Les copies `.sx.txt` restent des preuves, hors corpus actif.
