# Résidence entière X64 et dispatch exhaustif des protocoles

Candidat `40dc12052f4d03b646ba2210ec5b15013f338f77`, après correction
portable `76bd31d`, baseline `3e584015c9dc3a1cbfa687c7e36ba6bf75eab28d`.

Les régions entières X64 admettent les émetteurs mémoire qui préservent r8 à
r11 et épinglent leurs entrées/sorties réellement consommées en pile. Les
allocations, opérations d'ownership et appels restent des barrières volatiles.
La vivacité CFG distingue les sorties froides du corps répété ; les adresses
épinglent toujours leur span complet. Les copies entre couleurs entières
emploient un transfert direct ou disparaissent lorsque les couleurs coïncident.
Les transferts mixtes conservent les 64 bits de leur valeur.

Le témoin a révélé une IR brute invalide préexistante dans le dispatch des
protocoles : le chemin sans témoin rejoignait la fusion sans définir le résultat
ou le récepteur mis à jour. Le dernier type conforme est désormais le cas
exhaustif de cette liste connue à la compilation. Le vérificateur reste strict.
Le test différentiel couvre un et plusieurs témoins, retours et modifications ;
la contre-preuve avec l'ancien frontend échoue sur la dominance. Le corpus
natif vérifie aussi les copies de structures et les alias de classes.

Le portail exact passe 49/49 étapes, 2166 tests internes et 184 tests de langage.
L'oracle passe 31/31 étapes et 74 tests : 57 régressions fixes, huit scénarios,
64 erreurs entières et 43 conversions, en ARM64 physique puis X64 sous Rosetta.
La robustesse passe 144 paires, cinq triplets, 41 cas natifs, quatre négatifs et
les stress cache/graphe. Seize émissions et huit exécutions macOS Debug/Release
passent ; les cinq autres plateformes natives attendent leurs jobs exacts.
Le test d'assets embarqués interrompu lors d'un premier portail repasse isolément
et dans la suite finale. Le journal macOS conserve le refus d'exécution observé ;
aucun contournement de sécurité ni changement de ce test n'a été appliqué.

Objects.calculate X64 passe statiquement de 340 à 325 instructions et de 114
à 87 accès pile ; Arithmetic passe de 98 à 90 instructions. Ces comptes de
fonctions entières incluent les chemins froids et ne prouvent pas un gain.
Flocking X64, Arithmetic/Flocking ARM64 et les sections machine des deux noyaux
Physics restent identiques. Objects ARM64 est stable et neutre :
8.660333 → 8.791208 ms, ratio 1.009801 (0.995152..1.033632), 21 rotations et
six échauffements sur Apple M3 Pro physique. Sa parité reste rouge.

La variante initiale terminant le dispatch par panic est préservée hors produit
dans ProtocolPanicCandidate sous le répertoire temporaire de preuves. Ses blocs
froids empêchaient l'allocation entière. Elle n'est ni committée ni publiée.
Les campagnes GitHub du candidat final sont en cours ; aucun gain Intel de cette
tranche ni aucune clôture de la Part n'est revendiqué avant leurs résultats.

## Matrice native du candidat

Le run `34662126348` est entièrement vert : macOS X64, Linux ARM64/X64,
Windows X64, bootstrap Windows ARM64 puis exécution Windows ARM64 native.
Les six journaux et le statut des jobs sont conservés. Ils portent exactement
`40dc12052f4d03b646ba2210ec5b15013f338f77` ; les modifications suivantes
ne réutilisent pas ces résultats comme preuve de leur propre code.
La campagne Intel appariée `34662127944` reste en cours.
