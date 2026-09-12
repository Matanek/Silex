# Erreurs arithmétiques X64 — 11 septembre 2026

Candidat : `6db574e3f2b5f55adde00b485371759e8d04f764`. Référence : `5d15ebe73626d73d2faa476ad1a481e1226f00c4`.

Le compilateur de référence ignore les dépassements et produit des `SIGFPE`
pour la division par zéro et le quotient/reste de `min(int) / -1`. La
reproduction Debug LLDB arrête précisément `idivq %rcx` avec RCX nul.
Les exécutables originaux restent sous `/private/tmp/silex-part03-evidence/` ;
leurs hashes, les commandes et les sources sont conservés ici.

Le candidat normalise les opérandes 8/16/32 bits, contrôle les opérations
faillibles et rejoint l’épilogue avec le statut interne approprié. Le point
d’entrée expose un code de processus 0/1, comme ARM64. Les opérations prouvées
non faillibles conservent leur chemin sans contrôle. La qualification permanente
comprend 64 erreurs et huit succès aux bornes, avec un préfixe observable exact.

## Résultats

- `check test install` : 49/49 étapes, 2140/2140 tests ; 183 tests de langage,
  63 fichiers. L’ancien test de séquence d’entrée a été adapté aux neuf octets
  ajoutés ; ses contrôles de sauvegarde/restauration restent présents.
- Portail optimizer : 31/31 étapes, 73/73 tests ; 128 programmes différentiels,
  32 LLVM ; corpus cumulatif et contrats structurels verts.
- Robustesse qualifiée : campagne cumulative verte ; rapport brut joint.
- ARM64 physique et X64 sous Rosetta : chacun 47 régressions fixes, huit
  scénarios générés, 64 erreurs et huit succès. Matrice séparée : 288 exécutions,
  sorties/erreurs/codes exacts, Debug et Release.
- 48 émissions ELF/PE couvrent six sources, quatre cibles et deux modes.
  Linux/Windows n’ont pas été exécutés localement.

`binary-after.json` est une étape intermédiaire avant normalisation du code de
sortie de division par zéro ; seule `integer-matrix.json` scelle le résultat
final. Les mesures temporelles du portail court ne constituent aucune preuve
de gain : elles ont chevauché la qualification de correction X64. Aucun résultat
Rosetta ne qualifie la performance d’un processeur X64 physique.

Les copies `.sx.txt` évitent de devenir des modules du corpus. Pour reproduire,
les copier avec leur extension `.sx` dans un consommateur déclarant
`{"sources":"."}`, puis compiler depuis la racine du groupe de worktrees avec
la commande enregistrée, en adaptant seulement les chemins.

L’audit suivant devra couvrir séparément les conversions numériques, dont les
contrôles X64 sont absents et dont le contrôle ARM64 présente un cas limite
avec la saturation de la reconversion de `max(uint64)`.
