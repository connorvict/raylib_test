# Project instructions

Applies to the entire repository. Write idiomatic Odin, with the project-specific naming and organization rules below taking precedence over external style guides. Do not restyle or rename unrelated existing code.

## Project layout

- This is a native Odin + Raylib application. The `src/` directory is one package; `src/main.odin` handles the application loop, scene drawing, render-pass orchestration, controls, and UI; `src/renderer.odin` contains scene-independent shader/framebuffer lifecycle and effect-processing helpers. Shaders and fonts live under `assets/`.
- Prefer longer, cohesive code in fewer files. Extend the existing files rather than creating a file for each type, feature, or helper.
- Keep related data declarations and procedures together. A long file or straightforward sequential procedure is not, by itself, a reason to split it.
- Do not break code into modules or new packages unless critically necessary. A required platform/build boundary or a genuinely independent dependency boundary may justify a split; line count, speculative reuse, or organizational neatness do not. Explain the necessity before introducing one.
- Odin packages are directory-based; adding another `.odin` file in the same directory does not create a new module. Keep the current package structure unless a concrete requirement demands otherwise. [2]
- Prefer direct code over layers of forwarding helpers, manager objects, plugin systems, or single-use abstractions.
- Keep scene models, placement, animation, cameras, geometry drawing, and the choice of scene-specific lighting shader in `main.odin`. Renderer helpers accept that lighting shader source from the application; they must not call application draw procedures or depend on exhibit data. Orchestrate geometry passes explicitly in `main` rather than adding callbacks to hide scene rendering inside the renderer.

## Naming

- Name project-owned procedures in `noun_action` snake_case: the subject first, then the operation. Use `renderer_load`, `renderer_unload`, `renderer_render`, `effect_shader_load`, `effect_targets_resize`, `typography_refresh`, and `text_draw`, not `load_renderer` or `draw_text`.
- Declare procedures with Odin syntax, for example `renderer_resize :: proc(renderer: ^Renderer, width, height: i32) { ... }`. When operating on a particular state value, put that value first in the parameter list.
- Exceptions are required entry points such as `main` and names imposed by external interfaces. Keep imported API names intact; do not wrap Raylib merely to change its naming.
- Use snake_case for variables, fields, and import aliases; prefer short, recognizable aliases such as `rl` and `rgl`.
- Use Ada_Case for new types and enum members (`Render_Target`, `Shader_Error`, `.Not_Found`), and SCREAMING_SNAKE_CASE for value constants (`SHADOW_SIZE`). Preserve existing names unless the task requires changing them. [1]
- The noun-first procedure rule is a project convention, not a universal Odin requirement; the official examples guide prescribes snake_case without mandating noun/verb order. [1]

## Idiomatic Odin

- Model state as plain structs and behavior as free procedures. Pass state explicitly rather than emulating classes, methods, inheritance hierarchies, or pervasive mutable globals. Odin's design centers on data transformation and simplicity. [3]
- Prefer `:=` when the initializer makes the type clear: `renderer := renderer_load(lighting_fragment)`. Use explicit types for zero-initialized state, numeric precision, union values, or otherwise meaningful constraints. [1, 2]
- Prefer struct initializers over declaring a value and assigning each field separately. Use named fields when they clarify a larger initializer: `target := Render_Target{width = width, height = height}`. [1]
- Rely on Odin's default zero initialization when zero is a valid initial state. Avoid `= ---` unless measured performance and guaranteed initialization justify it. [2]
- Prefer typed enums, `bit_set`, and tagged unions to magic integers, hand-rolled flag arithmetic, or untyped variant payloads. Use inferred enum members such as `.ORTHOGRAPHIC` when the type is clear. [2]
- Use Odin's native arrays, slices, dynamic arrays, maps, range loops, and multiple return values instead of recreating standard containers or iterator frameworks. Use `for &value in values` when elements must be mutated. [2]
- Keep package-qualified calls explicit. Avoid broad `using` declarations that obscure where names or fields come from. Do not introduce generics or procedure overload sets without an actual need.
- Use `when` for compile-time choices and `if` for runtime choices; do not simulate a C preprocessor. [2]
- Read the installed `core:` and `vendor:` source when unsure about an API. Match the installed Odin version rather than assuming examples from another release still apply.

## Memory, resources, and errors

- Odin uses manual memory management. Make ownership and lifetime clear for allocated memory, slices, strings, and Raylib handles. A slice is a view of storage, not an independent owning allocation. [2]
- Use allocator-aware APIs. `context.allocator` is the default general-purpose allocator; `context.temp_allocator` is for temporary storage. Dynamic arrays and maps retain their own allocator. Do not assume changing the context changes existing containers. [2]
- Temporary memory must not escape its lifetime. Reset scratch storage only at an owning boundary where no live references remain, such as the end of a frame; `free_all(context.temp_allocator)` invalidates allocations made through that allocator. [2]
- Pair acquisition with the correct release operation: `delete` for appropriate Odin allocations, and the corresponding Raylib unload/close API for Raylib resources. Avoid double frees or freeing borrowed storage.
- Use `defer` when it makes cleanup reliable across early returns or multiple exit paths. Do not scatter deferred operations through otherwise linear code solely by habit; cleanup should remain easy to follow. [1, 2]
- Treat `string` and `cstring` as different representations. Ensure foreign strings are NUL-terminated and remain valid for as long as the C API requires. Keep raw pointers and unsafe casts confined to foreign API boundaries. [2]
- Return and check explicit errors or `ok` values. Prefer meaningful error enums and multiple return values over exceptions or an invented universal error framework. Reserve assertions for invariants or deliberately fatal failures, not recoverable input errors. [2, 3]
- In rendering code, reuse persistent GPU resources and rebuild size-dependent targets only when necessary. Avoid unnecessary allocation or resource loading in the frame loop; optimize further only with evidence.

## Formatting and change discipline

- Use tabs for indentation and spaces for alignment, with opening braces on the declaration/control-flow line. Omit unnecessary semicolons and use braced blocks rather than `do`. [1]
- Expand control-flow blocks onto multiple lines in new or changed code. Separate logical phases with blank lines; do not reformat untouched code.
- Use self-explanatory names and minimal comments. Comments should explain non-obvious constraints, ownership, or rationale rather than narrate statements.
- Make the smallest change that solves the requested problem. Do not introduce packages, dependencies, configuration options, or abstractions for hypothetical future needs.

## Verification

Run from the repository root after Odin changes:

```sh
odin check src
odin check src -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors
odin build src -out:museum
```

For visual or input changes, also run `odin run src` in a graphical environment and exercise the affected behavior. Rendering changes should be checked with effect toggles and window resize/DPI changes. Do not claim a visual check if no graphical session was available. Run relevant tests when present; add focused regression coverage where practical.
