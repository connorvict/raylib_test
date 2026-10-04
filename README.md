# FORM — a small native museum

An Odin + vendored Raylib **6.0** sample: a lit cube, sphere, and torus on plinths, filtered directional shadows, contact shading, SSAO, world-anchored exhibit labels, and an Inter typography specimen.

## Run

Requires Odin with `vendor:raylib` 6.0 and a desktop OpenGL 3.3 driver.

```sh
odin run .
```

Or build a binary:

```sh
odin build . -out:museum -vet -strict-style
./museum
```

Uses Odin's vendored Raylib configuration; this installation supplies the shared library. Fonts and shaders are embedded in the executable, so launching from another working directory works. There are no runtime asset downloads.

## Controls

- Drag in the gallery, or use arrow keys: orbit.
- Mouse wheel in the gallery: zoom.
- Space: pause object animation.
- 1: toggle directional shadows.
- 2: toggle approximate contact AO.
- 3: toggle SSAO.
- R: reset the view and animation.
- F12: save `museum.png` to the current working directory.
- Escape: quit.

The window is resizable, with a 1100 × 720 minimum.

## Rendering and typography

- `MSAA_4X_HINT` is set **before** `InitWindow`. The final lit scene, UI shapes, and text draw directly to the window framebuffer. Single-sample auxiliary textures supply shadows and AO; the final image is not a single-sample fullscreen composite, so geometry keeps window MSAA. Startup queries the actual sample count directly from the platform OpenGL library (`OpenGL.framework` on macOS), without requiring `rlgl.GetProcAddress` in Odin's bindings; a warning and on-screen notice appear if the driver cannot supply four samples.
- MSAA smooths geometry edges; it does not fix a low-resolution font atlas. Inter is rasterized separately for each displayed type size, at `GetRenderHeight() / GetScreenHeight()` density. Atlases rebuild when that ratio changes.
- Text uses existing antialiased glyph coverage, point filtering, zero extra letter spacing, and pixel-snapped positions. Each atlas texel maps to a framebuffer pixel instead of enlarging Raylib's default bitmap font. `WINDOW_HIGHDPI` is enabled; OS/compositor scaling support still depends on the Raylib backend.
- `TYPE_SIZES` owns typography; `PAPER`, `INK`, `MUTED`, `RULE`, and `TEAL` own the shared UI palette. Screen coordinates are logical pixels; exhibit labels are projected from world coordinates.
- One shared scene-drawing function supplies all geometry passes, keeping animated transforms consistent between shadows, SSAO, and final lighting.
- Text supports printable ASCII and Latin-1, including the specimen's accented letters. This is a rendering sample, not a text editor or a shaping/fallback engine. Raylib's custom-drawn UI does not expose native screen-reader semantics.

## Shadows and ambient occlusion

All three effects start enabled; keys 1–3 toggle them independently.

1. **Directional shadows:** a 2048 × 2048 packed-depth shadow map, tight orthographic light frustum, slope-aware depth bias, and 3 × 3 PCF. The map updates with the objects; shadowing affects the main directional light.
2. **Contact AO:** analytical soft darkening around pedestal footprints and exhibit contacts. It replaces the old solid discs and modulates ambient light. This is an intentional scene-specific approximation, not another shadow map.
3. **SSAO:** a half-framebuffer-resolution RGBA32F normal/depth pass, view-position reconstruction compatible with the orthographic camera, 32 hemisphere samples, and a 7 × 7 bilateral blur using normals and surface-plane distance to smooth sloped surfaces without bleeding across geometry edges. The final shader performs edge-aware upsampling and applies occlusion to ambient lighting rather than painting it over text or the background.

`renderer.odin` owns the passes and GPU resources; `assets/shaders/` contains the GLSL 330 shaders. Size-dependent targets rebuild on framebuffer-size changes, including Retina density changes. Data passes disable alpha blending so stored depth is not corrupted.

Tune `SHADOW_SIZE`, `SHADOW_BIAS`, `AO_RADIUS`, and `AO_STRENGTH` in `renderer.odin`. The single shadow map covers this museum, not an unlimited world; SSAO cannot see off-screen or hidden occluders. macOS uses desktop OpenGL without compute shaders or the missing `rlgl.GetProcAddress` helper.

## Runnable smoke check

Run on a desktop with a graphics context:

```sh
odin build . -out:museum -vet -strict-style
./museum --smoke-test
```

The check asserts actual 4x MSAA, font/shader/model loading, an accented glyph, text measurement, overlay pixels, screenshot dimensions, target resizing, and no OpenGL errors. It compares each effect independently against an unshaded baseline, requiring visibly darker scene pixels. It also checks that AO filtering reduces neighboring-pixel variation without darkening the background, renders a rotated camera/object view, and resizes to 1100 × 720.

It exits after fifteen frames and writes `_smoke-large.png`, `_smoke-small.png`, `_smoke-orbit.png`, `_smoke-none.png`, `_smoke-shadows.png`, `_smoke-contact.png`, and `_smoke-ssao.png` for visual inspection. It deliberately fails if the driver does not provide MSAA. A real high-DPI monitor is needed to verify compositor behavior.

## Bundled Inter fonts

Unmodified **Inter 4.1**, by Rasmus Andersson, from the [official release](https://github.com/rsms/inter/releases/tag/v4.1):

- `assets/fonts/Inter-Regular.ttf` — `extras/ttf/Inter-Regular.ttf`
- `assets/fonts/Inter-SemiBold.ttf` — `extras/ttf/Inter-SemiBold.ttf`
- `assets/fonts/OFL.txt` — upstream license and copyright notice

Inter is distributed under the SIL Open Font License 1.1. Keep `OFL.txt` with redistributions of the bundled fonts, including embedded distributions.
