# Opérandes entiers X64 directs

Candidat `b8d01d73233a88a080170b53096f2a72bbd8d98e`, baseline
`901c6f5594841a277da00c53c29051bb7ab23076`. Compilateur local figé :
`d19794be31e2f5bedc555a190e9160579f64bf84aaa3b91d69d76d00232eb94a`.

Les opérations entières 64 bits utilisent leurs couleurs directement. Un
résultat réutilisant l'opérande droit passe temporairement par scratch ; les
branches de dépassement conservent leur statut et leur épilogue. Les opérations
étroites et la multiplication non signée contrôlée gardent leur chemin normalisé.
Les comparaisons fusionnées 64 bits lisent les registres alloués ; les comparaisons
étroites normalisent uniquement des copies pour préserver leurs entrées vivantes.

Le test réduit échoue avant. Les 61 tests X64 passent, et retirer la protection
du résultat réutilisant l'opérande droit produit bien TestExpectedEqual.
Le portail complet passe 49 étapes, 2169 tests internes et 184 tests de langage.
L'oracle passe 31 étapes et 74 tests, avec 57 régressions fixes, huit scénarios,
64 erreurs entières et 43 conversions, également qualifiés sur X64 Rosetta.
La robustesse passe 144 paires, cinq triplets, 41 natifs, quatre négatifs et
les stress cache/graphe. Les 28 émissions et 12 exécutions macOS Debug/Release
ont des sorties exactes : 18 contrôles entiers, 22 contrôles mixtes et le
corpus de portabilité. Le témoin signé utilise les opérateurs arithmétiques
admis ; les opérateurs bit à bit restent testés sur uint.

Les trois binaires généraux ARM64 sont inchangés. Arithmetic X64 passe de 90
à 80 instructions dans sa première fonction. Les textes complets Objects et
Flocking passent de 1436 à 1428 et de 1862 à 1853 instructions. Les périmètres
incluent les chemins froids et, sauf Arithmetic, le runtime ; ces comptes
ne démontrent aucun gain physique.

Les trois jobs natifs du SHA exact sont verts : macOS X64 `34664716155`
(job `103474213127`), Linux X64 `34664717182` (job `103474215712`) et Windows
X64 `34664718405` (job `103474218530`). Journaux et métadonnées sont scellés.
La campagne Intel `34664959587` contre `901c6f5` est terminée. Ses régressions
passent ; l'admission échoue aux mesures. Sur Intel i7-8700B physique, Darwin
24.6.0, Apple Clang 17, 21 paires et six échauffements donnent :

- Flocking : 1513.579704 → 1275.196745 ms, ratio apparié 0.854412,
  intervalle 0.835205..0.889002, stabilité verte : gain qualifié de 14.56 %.
- Arithmetic : 6.272102 → 5.705994 ms, ratio 0.906559,
  intervalle 0.894665..0.931504. Aucun gain qualifié : la dérive de la
  référence atteint 112087 ppm, au-delà des 100000 ppm admis.
- Objects : 11.304118 → 11.643304 ms, ratio 1.042010,
  intervalle 1.025847..1.049438, stabilité verte. Le ralentissement mesuré
  de 4.20 % doit être attribué avant admission : la campagne précédente
  donnait déjà +4.46 % entre deux exécutables strictement identiques.
  Le contrôle séparé `34666742724` recompare les exécutables archivés dans
  les deux sens, puis compare des copies identiques et un même fichier.

La parité face à Clang -O3 à slots de huit octets reste rouge : ratios
1.076609 / 2.407725 / 2.642036 pour Arithmetic / Objects / Flocking.
Les seuils sont inchangés. L'artefact `10289735715` a pour SHA-256
`432eae5ec4f0b0fa482e4b309cfdb5318a8fef651e4d98ba92e5d320dabd8df1` ;
les quinze exécutables sont vérifiés. Les données et journaux bruts sont
conservés dans cet audit ; le contrôle diagnostique sera scellé séparément.

Le corps répété d'Arithmetic contient 38 → 28 instructions, dont 17 → 7
copies de registres ; le chemin de dépassement est conservé. Les dix suppressions
sont dans cette zone chaude. Les sections machine des noyaux Preparation et
Integration ARM64 recompilés sont identiques à `40dc120` : 42756 et 49860 octets.
Les déficits de parité Physics mesurés auparavant ne sont donc pas résolus.
