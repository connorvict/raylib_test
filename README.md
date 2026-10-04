# FORM — a small native museum

An Odin + vendored Raylib **6.0** sample: a lit cube, sphere, and torus on plinths, world-anchored exhibit labels, and an Inter typography specimen.

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

Uses Odin's vendored Raylib configuration; this installation supplies the shared library. Fonts are embedded in the executable, so launching from another working directory works. There are no runtime asset downloads.

## Controls

- Drag in the gallery, or use arrow keys: orbit.
- Mouse wheel in the gallery: zoom.
- Space: pause object animation.
- R: reset the view and animation.
- F12: save `museum.png` to the current working directory.
- Escape: quit.

The window is resizable, with a 1100 × 720 minimum.

## Rendering and typography

- `MSAA_4X_HINT` is set **before** `InitWindow`. The scene, UI shapes, and text draw directly to the window framebuffer, not a single-sample render texture. Startup queries the actual OpenGL sample count; a warning and on-screen notice appear if the driver cannot supply four samples.
- MSAA smooths geometry edges; it does not fix a low-resolution font atlas. Inter is rasterized separately for each displayed type size, at `GetRenderHeight() / GetScreenHeight()` density. Atlases rebuild when that ratio changes.
- Text uses existing antialiased glyph coverage, point filtering, zero extra letter spacing, and pixel-snapped positions. Each atlas texel maps to a framebuffer pixel instead of enlarging Raylib's default bitmap font. `WINDOW_HIGHDPI` is enabled; OS/compositor scaling support still depends on the Raylib backend.
- `TYPE_SIZES` owns typography; `PAPER`, `INK`, `MUTED`, `RULE`, and `TEAL` own the shared UI palette. Screen coordinates are logical pixels; exhibit labels are projected from world coordinates.
- A small directional-light shader shades the models. Contact-shadow discs are illustrative, not physically accurate dynamic shadows.
- Text supports printable ASCII and Latin-1, including the specimen's accented letters. This is a rendering sample, not a text editor or a shaping/fallback engine. Raylib's custom-drawn UI does not expose native screen-reader semantics.

## Runnable smoke check

Run on a desktop with a graphics context:

```sh
odin build . -out:museum -vet -strict-style
./museum --smoke-test
```

The check asserts actual 4x MSAA, custom font/shader/model loading, an accented glyph, text measurement, rendered overlay pixels, screenshot dimensions, and resizing to 1100 × 720. It exits after ten frames and writes `_smoke-large.png` and `_smoke-small.png` for visual inspection. It deliberately fails if the driver does not provide MSAA. A real high-DPI monitor is needed to verify compositor behavior.

## Bundled Inter fonts

Unmodified **Inter 4.1**, by Rasmus Andersson, from the [official release](https://github.com/rsms/inter/releases/tag/v4.1):

- `assets/fonts/Inter-Regular.ttf` — `extras/ttf/Inter-Regular.ttf`
- `assets/fonts/Inter-SemiBold.ttf` — `extras/ttf/Inter-SemiBold.ttf`
- `assets/fonts/OFL.txt` — upstream license and copyright notice

Inter is distributed under the SIL Open Font License 1.1. Keep `OFL.txt` with redistributions of the bundled fonts, including embedded distributions.
