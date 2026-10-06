# FORM

A native Odin + `vendor:raylib` 6.0 museum: three 3D exhibits, Inter typography, directional shadows, contact AO, and smooth SSAO. Requests 4× MSAA and renders the final scene directly to the window.

Requires Odin with Raylib 6.0 and desktop OpenGL 3.3.

```sh
odin run src
```

To build:

```sh
odin build src -out:museum
./museum
```

**Controls:** drag/arrows orbit, scroll zooms, Space pauses, R resets, Escape quits. Keys **1/2/3** toggle shadows/contact AO/SSAO; **F12** saves `museum.png`.

`src/main.odin` contains the scene, lighting shader selection, render-pass orchestration, window, UI, and controls; `src/renderer.odin` contains shader/framebuffer management, effect-processing helpers, and tuning constants; `assets/shaders/` contains GLSL. Fonts and shaders are embedded, and size-dependent resources rebuild on resize/DPI changes.

Bundled [Inter 4.1](https://github.com/rsms/inter/releases/tag/v4.1) is licensed under SIL OFL 1.1. Keep `assets/fonts/OFL.txt` with redistributions, including embedded fonts.
