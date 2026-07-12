# Silex

Silex est un langage de programmation compilé. Son premier backend génère du
C++, puis invoque la toolchain native pour produire un exécutable.

Le projet recherche une syntaxe concise et familière sans exposer les détails
d'implémentation du C++ généré.

## État du prototype

Le premier noyau accepte un point d'entrée, les variables locales, les
booléens, les conditions et les expressions arithmétiques entières :

```sx
void main() {
    let a = 5;
    let b: int = 10;
    var hit: bool = true;

    print("Hello World");

    if (hit && a < b) {
        print(a * b);
    } else {
        print("blocked");
    }

    var count = 3;
    while (count > 0) {
        print(count);
        count = count - 1;
    }
}
```

`let` déclare une valeur immuable et `var` une variable réaffectable. Le type est
inféré lorsque l'annotation `: type` est absente. Les opérateurs disponibles
sont `+`, `-`, `*`, `/`, les comparaisons `==`, `!=`, `<`, `<=`, `>` et `>=`,
ainsi que les opérateurs logiques `!`, `&&` et `||`. Une condition `if` exige
une expression booléenne et peut être suivie d'un bloc `else`. Une boucle
`while` réévalue une condition booléenne avant chaque itération.

La commande `compile` produit un exécutable natif. La commande `run` compile et
exécute le programme :

```sh
silex compile path/to/Main.sx
silex run path/to/Main.sx
```

Les artefacts sont regroupés dans `.silex/` sous le dossier depuis lequel la
commande est lancée. Un programme inchangé réutilise l'exécutable présent dans
le cache de compilation.

## Organisation

```text
Silex/
├── Editors/
│   └── Zed/           extension Zed et grammaire Tree-sitter
└── Toolchain/         projet Zig autonome
    ├── Sources/       implémentation de la commande silex
    ├── Tests/         programmes invalides et diagnostics attendus
    └── Smokes/        programmes .sx compilés de bout en bout
```

## Construire la toolchain

La toolchain nécessite Zig 0.16 :

```sh
cd Toolchain
zig build
```

Le binaire est produit dans `Toolchain/zig-out/bin/`. Il peut être invoqué avec
son chemin ou installé dans un dossier présent dans le `PATH` de la plateforme.

Les vérifications sont disponibles avec :

```sh
cd Toolchain
zig build test
zig build smoke
```

## Zed

L'extension située dans `Editors/Zed/` associe les fichiers `.sx` au langage
Silex. Elle fournit la coloration syntaxique, les paires de délimiteurs,
l'indentation, le plan des fonctions et quelques snippets.

Elle s'appuie sur la grammaire native `tree-sitter-silex` développée dans
`Editors/Zed/TreeSitter/`.

Pour l'utiliser pendant le développement, exécuter `zed: install dev extension`
dans Zed, puis sélectionner le dossier `Editors/Zed/`.
