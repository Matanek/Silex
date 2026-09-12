# Rejet de la fusion de parité X64

Verdict : transformation rejetée et retirée. La branche revient par
`a92677a` au produit exact de la référence qualifiée
`c3a4b391f4d6ba3e656ee66fb82bc57fe7a13beb` pour les fichiers concernés.
Aucun résultat de performance Intel n'est attribuable à cet essai : les trois
campagnes ont échoué pendant la qualification fonctionnelle, avant la mesure.

L'expérience cherchait à remplacer la séquence `% 2`, comparaison à zéro et
branche par un test du bit faible. Une variante `% 4` par masque a aussi été
isolée. Les mesures locales exécutent des binaires macOS X64 sous Rosetta sur
un hôte ARM64 ; elles sont uniquement diagnostiques. Chaque série comporte
21 observations, six échauffements, quatre lancements par configuration et
observation, avec rotation équilibrée et intervalle bootstrap sur la médiane
des ratios appariés.

La variante qui teste directement la parité donne deux ratios candidat/référence
de 1.010993, intervalle 0.996650..1.023527, puis 1.005396, intervalle
1.000022..1.026300. Le masque donne 1.030697, intervalle
1.016447..1.045168, puis 1.035980, intervalle 1.018487..1.052032. Rosetta ne
prouve pas le coût Intel, mais ces répétitions ne fournissent aucun motif de
gain et rejettent localement le masque.

Trois candidats ont ensuite été éprouvés sur un Intel Core i7 physique :

- `7d5e1fa2e8bdff19a90c464d3d527ef21425af08`,
  [run 34685630351](https://github.com/Matanek/Silex/actions/runs/34685630351) :
  échec Debug de `ScalarClassLeaves.sx` ;
- `28c16fa`,
  [run 34686423471](https://github.com/Matanek/Silex/actions/runs/34686423471) :
  même échec après matérialisation prudente dans `rax` ;
- `4ed6babb4678680823101b514c9a66bd565c276c`,
  [run 34687217645](https://github.com/Matanek/Silex/actions/runs/34687217645) :
  `ScalarClassLeaves.sx` passe après restriction aux opérandes prouvés
  non négatifs, puis `DominatedReferenceReads.sx` échoue en Release.

Le déplacement du défaut démontre que les seules utilisations de slots, la
non négativité et l'absence de cible de contrôle locale ne suffisent pas à
prouver l'équivalence après expansion X64. Une nouvelle tentative doit porter
la fusion comme une opération Machine explicite, ou fournir en amont un
contrat de sélection commun qui conserve valeur, drapeaux, vivacité et contrôle.
Ajouter d'autres exceptions dans l'encodeur n'est pas une trajectoire admise.

`measure_variants.py` est le protocole local conservé. Les deux JSON contiennent
les observations brutes et leurs hashes exécutables de session. Les trois
journaux GitHub Actions conservent les échecs natifs. Les exécutables locaux ne
sont pas archivés : ils proviennent d'un candidat rejeté et les JSON suffisent
à authentifier ceux qui ont été mesurés pendant la session.
