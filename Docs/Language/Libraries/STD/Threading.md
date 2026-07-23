# Threading

`STD.Threading` fournit un pool global fixe de workers et son ordonnanceur. Son
import canonique récupère naturellement le dernier segment du chemin :

```sx
use STD.Threading
```

`TaskManager` est une classe statique : l'application ne construit pas de
manager et ne choisit pas le nombre de workers. Le pool est créé à la première
soumission avec `max(1, logical_processor_count - 1)` workers.

Une tâche est une structure copiable qui implémente `Task`. Ses entrées et son
résultat sont des champs ordinaires ; une collection telle que `int[]` ne
demande aucun conteneur propre au système de tâches :

```sx
struct Sum:Threading.Task {
    let values:int[]
    var total:int

    func execute() {
        var result = 0
        for value in self.values {
            result += value
        }
        self.total = result
    }
}
```

`TaskManager.submit(task)` copie la tâche, exécute `execute()` une fois sur un
worker et conserve cette copie effectivement modifiée dans son handle. `T` est
normalement déduit de `task`; `submit<Sum>(...)` reste accepté.

Sans callback de soumission, `complete()` attend et retourne la tâche terminée :

```sx
var completed = Threading.TaskManager.submit(
    Sum(values:[1, 2, 3], total:0)
).complete()
assert(completed.total == 6, "sum completed")
```

Le résultat peut aussi être consommé par un callback de `complete`. Ce callback
s'exécute sur le thread qui appelle `complete`, après l'attente. Il peut donc
restituer efficacement une collection avec `move` :

```sx
var original = Sum(values:[1, 2, 3], total:0)
var handle = Threading.TaskManager.submit(original)
handle.complete(func(completed:Sum) {
    original = move completed
})
```

Enfin, un callback passé directement à `submit` est appelé automatiquement par
le worker après `execute()`. Le handle ne transporte alors plus de résultat ;
son `complete()` est une attente facultative :

```sx
var handle = Threading.TaskManager.submit(
    Sum(values:[1, 2, 3], total:0),
    func(task:Sum) {
        print(task.total)
    }
)
handle.complete() // facultatif si ce chemin doit attendre explicitement
```

Le callback automatique est isolé par contexte : ses captures doivent être des
valeurs indépendantes. Il peut appeler `print`; chaque émission reste entière,
mais l'ordre entre workers n'est pas garanti. Pour modifier une valeur du thread
appelant, il faut employer `complete(func(T))` ou récupérer le retour de
`complete()`.

Les handles concrets sont des classes génériques `internal` à
`STD/Threading.sx`. Le code client les conserve par inférence avec `var` et
découvre `complete` par autocomplétion, sans pouvoir importer ni construire ces
types. Copier un handle partage l'identité de la même tâche. Le résultat d'un
handle typé se consomme une fois, soit par `complete()`, soit par
`complete(func(T))`; le callback de soumission possède un handle d'attente
distinct, dont `complete()` peut être répété.

La copie initiale suit les règles d'indépendance de Silex : seules des données
récursivement indépendantes franchissent la frontière entre le thread appelant
et le worker. Une référence de classe, un protocole dynamique, un emprunt ou une
ressource unique ne peut donc pas être enfoui dans la tâche soumise.

Le corps de `execute()` n'est pas limité à ces types transportables. Il peut
créer, muter et détruire localement des classes, protocoles, callbacks,
collections et ressources selon les règles ordinaires du langage. Par exemple,
un `Randomizer.create()` construit dans `execute()` est confiné au worker et ne
partage pas son état avec le thread appelant. L'accès à `static var` reste
refusé, et un `static let` doit être récursivement indépendant.

Une exception native levée sur le worker est mémorisée puis relevée par un appel
explicite à `complete`; la destruction du handle attend et libère toujours les
données restantes sans lancer depuis un destructeur.

La composition publique — protocole, pool statique, surcharge de `submit`,
handles et callbacks — est écrite dans `STD/Threading.sx`. Le C++ se limite à la
création des threads, la file synchronisée, l'attente et au transport d'un
résultat opaque. Il ne connaît ni `Task`, ni le type concret, ni ses champs. La
toolchain ne reconnaît aucun nom particulier de `STD.Threading`.

Cette API ne fournit encore ni annulation, priorité, dépendances, sondage non
bloquant, état partagé arbitraire, mutex public, work stealing ou exécution
parallèle par index. Les défaillances d'infrastructure restent fatales, de sorte
que l'usage courant n'impose ni `try` ni `trymove`.
