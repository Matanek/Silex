# Portail d’admission et portabilité native

Candidat de code : `41a99f13a6b0558e7c897cddeeb2ec1a94074661`.
Workflow autorisé : https://github.com/Matanek/Silex/actions/runs/34620188559
Verdict final : succès, six jobs attendus verts, `optimizer-x64` non sélectionné.

## Correction

Le build compile désormais son admission pour l’hôte et l’exécute depuis
Toolchain, y compris lors d’un bootstrap Windows ARM64 construit sur Linux.
La fixture de plateforme est vérifiée pour les six cibles ; son fragment
inactif reste volontairement invalide. Les attentes de chemins utilisent le
séparateur natif. Les tests de rétention ouvrent leurs fichiers en lecture et
écriture pour modifier leurs dates, espacées en secondes pour préserver
l’ordre sur les systèmes de fichiers à résolution moins fine.
Le workflow copie la source scalaire sans modification dans un consommateur
sans STD. Aucun backend, seuil de parité ni seuil de durée n’est changé.

## Validation locale

La fixture antérieure échoue avec une cible Linux explicite : 176/177 tests.
Après correction, l’admission invoquée depuis la racine avec
`-Dtarget=aarch64-windows` exécute 177/177 tests sur l’hôte macOS ARM64.
Le YAML et les 14 corps Bash sont vérifiés ; le consommateur scalaire isolé
émet un ELF ARM64 et conserve exactement les octets de la source.

Le premier portail complet donne 2149/2150 tests et 183 tests de langage verts ;
le seul échec est le test chronométré LSP pendant plusieurs compilations
concurrentes. Les deux durées de ce premier échec n’étaient pas journalisées,
sa cause précise n’est donc pas prouvée. Le diagnostic des durées est ajouté
sans relever le seuil de cinq secondes. La suite LSP isolée passe 425/425,
puis le portail final passe 49/49 étapes, 2150/2150 tests et 183 tests de langage.
Les journaux du premier échec, du contrôle isolé et du portail final sont conservés.

## Exécution distante

Les jobs macOS X64, Linux ARM64, Linux X64, Windows X64 et Windows ARM64
sont verts sur le même SHA, ainsi que le bootstrap intermédiaire Windows ARM64.
Linux et Windows exercent notamment les neuf observations du nouveau témoin
scalaire, en Debug et Release. Les journaux complets, statuts et métadonnées
du bootstrap sont conservés ; son archive binaire n’est pas dupliquée ici.
Le Mac ARM64 local porte les preuves hôte précédentes et le portail complet.

## Limite de clôture

La campagne physique Intel sur `ebc20fb` est scellée séparément dans
`2026-09-11-intel-scalar-residence`. Elle passe la correction mais échoue
à la parité et à la stabilité face au comparateur historique Clang `-O2`.
Cette réparation du portail ne change pas le code machine et ne résout pas
les écarts Intel ou Physics ARM64. La Part 03 reste active.

Le manifeste scelle chaque fichier de cet audit. Les changements ultérieurs
qui ajoutent seulement cet audit ne constituent pas un nouveau candidat machine.
