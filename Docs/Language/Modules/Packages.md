# Use source packages

A source package keeps its modules under `Module/`:

```text
Math/
  Package.json
  Module/
    Vec3.sx
```

Its directory name and manifest identity match:

```json
{
  "name": "Math",
  "version": "1.4.1"
}
```

## Declare a dependency

```json
{
  "dependencies": {
    "Math": "^1.4.0",
    "Silex.Bootstrap": "=0.1.0"
  }
}
```

Use `^` for a compatible version range or `=` for one exact version.

Silex first checks a compatible sibling package, then installed packages under
`~/.silex/packages/Name@MAJOR.MINOR.PATCH/`.

Dependencies are direct. Declare every package used by the application; a
transitive dependency is not automatically visible.
