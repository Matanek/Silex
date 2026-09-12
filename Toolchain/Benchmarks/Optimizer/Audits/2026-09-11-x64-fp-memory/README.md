# Résidences flottantes X64 autour des copies mémoire

Le candidat `6530e140752f3d93f2f1226926be254c04e90760` distingue les émetteurs
qui conservent la banque FP mais utilisent des opérandes en pile. Copies de
plages, agrégats et chargements/comptes de collections épinglent tous leurs
opérandes et résultats ; ils ne forcent plus les flottants indépendants en pile.
Les barrières d’appel et les valeurs adressées restent protégées.

Le compilateur local SHA-256 est
`ed4cf646c0977bce791c545aa55b9f0bfebcbba1015f7addb18b5b7812f5f6fc`.
La référence est `225ba12f8d8b4f2e434c0ae18bd0b6269c909373`.

Le portail passe 49/49 étapes, 2158 tests internes et 183 tests de langage.
L’oracle passe 31/31 étapes, 74 tests, 53 cas fixes, huit générés, 64 erreurs
entières et 43 conversions. La même qualification native X64 sous Rosetta
passe. Robustesse : 144 paires, cinq triplets, 41 natifs, quatre négatifs,
stress du cache et du graphe verts. Les douze émissions du témoin passent ;
les quatre exécutions macOS ARM64/X64 donnent sept lignes `true` chacune.

Les cinq tests ciblés passent. La mutation qui rétablit les barrières complètes
échoue sur l’assertion de résidence indépendante. L’émetteur garde tous les
opérandes de copie en pile et les valeurs traversant un appel restent épinglées.
Les deux erreurs initiales d’annotation dans le nouveau témoin sont corrigées
avant qualification ; le fichier `native-initial` garde le rejet initial.

Les trois exécutables ARM64 restent identiques au candidat précédent.
Arithmetic et Objects X64 restent également identiques. Flocking X64 change :
le comptage statique de sa seconde fonction passe de 541 à 525 instructions
et de 202 à 190 accès pile. Ce comptage ne prouve ni une fréquence exécutée
ni un gain temporel. La fonction `steer` reste inchangée ; sa sonde machine
identifie deux retours terminaux qui épinglent encore des valeurs utilisées
uniquement dans l’autre branche.

Aucune mesure Intel physique ni matrice distante n’est revendiquée pour ce
checkpoint intermédiaire. Elles seront exécutées sur le candidat cumulatif
après la correction ciblée des retours exclusifs. La Part 03 demeure active.
`manifest.json` scelle les preuves locales et les exécutables.
