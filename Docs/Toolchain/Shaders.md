# Compile portable HLSL

Silex owns shader compilation so an installed application does not need a
shader compiler. Install the verified Shadercross tool once:

```sh
silex setup
```

`GPU.ShaderProgram.hlsl` accepts either a source string known at compile time
or a file relative to the Silex source containing the call:

```sx
let inline_source = "..."
let inline_program = GPU.ShaderProgram.hlsl(source:inline_source)

let file_program = GPU.ShaderProgram.hlsl(
    file:"Shaders/World.hlsl",
    vertex:"vertex_main",
    fragment:"fragment_main"
)
```

`GPU.ComputeProgram.hlsl` applies the same contract to a compute entry point.
Shadercross reflection supplies the resource counts and compute thread-group
dimensions required by SDL_GPU.

During frontend compilation Silex:

1. requires `source`, `file`, and entry-point names to be compile-time strings;
2. resolves shader files relative to the calling `.sx` file;
3. invokes the host Shadercross tool for each stage and target format;
4. reports HLSL diagnostics with their original line and column;
5. embeds the compiled variants and reflection in typed Silex IR;
6. records file sources and quoted includes as compilation-cache dependencies.

The target bundle currently contains MSL on `macos-arm64`, SPIR-V on
`linux-x64`, and both DXIL and SPIR-V on Windows. GFX selects the variant
accepted by the SDL_GPU device at runtime. Backend-specific `device.shader`
and `device.compute_pipeline` overloads remain available as the explicit
low-level path.

An invalid file diagnostic is reported against the HLSL source itself:

```text
Shaders/World.hlsl:18:12: error: use of undeclared identifier 'camera'
```

For an inline string the `.sx` call site remains the primary location and the
message carries the precise HLSL coordinates:

```text
Main.sx:9:49: error: HLSL 3:17: use of undeclared identifier 'camera'
```
