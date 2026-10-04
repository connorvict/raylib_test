package museum

import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"
import rgl "vendor:raylib/rlgl"

when ODIN_OS == .Darwin {
	foreign import desktop_gl "system:OpenGL.framework"
} else when ODIN_OS == .Windows {
	foreign import desktop_gl "system:opengl32.lib"
} else {
	foreign import desktop_gl "system:GL"
}
foreign desktop_gl {
	glGetIntegerv :: proc "system" (pname: u32, data: ^i32) ---
	glGetError :: proc "system" () -> u32 ---
}

INTER_REGULAR :: #load("assets/fonts/Inter-Regular.ttf", []u8)
INTER_SEMIBOLD :: #load("assets/fonts/Inter-SemiBold.ttf", []u8)

PAPER :: rl.Color{247, 246, 242, 255}
INK :: rl.Color{36, 43, 44, 255}
MUTED :: rl.Color{99, 105, 103, 255}
RULE :: rl.Color{215, 216, 208, 255}
TEAL :: rl.Color{42, 119, 117, 255}

Type :: enum {
	Small,
	Body,
	Subtitle,
	Heading,
	Title,
	Label,
}
TYPE_SIZES :: [Type]int {
	.Small    = 14,
	.Body     = 18,
	.Subtitle = 24,
	.Heading  = 32,
	.Title    = 48,
	.Label    = 18,
}
Typography :: struct {
	fonts:   [Type]rl.Font,
	density: f32,
}

refresh_type :: proc(type: ^Typography, density: f32) {
	if type.density == density {return}
	sizes := TYPE_SIZES
	for role in Type {
		if type.density > 0 {rl.UnloadFont(type.fonts[role])}
		data := INTER_REGULAR
		if role == .Heading || role == .Title || role == .Label {
			data = INTER_SEMIBOLD
		}
		codepoints: [191]rune
		for &codepoint, i in codepoints {
			codepoint = rune(32 + i) if i < 95 else rune(160 + i - 95)
		}
		pixels := i32(math.ceil(f32(sizes[role]) * density))
		font := rl.LoadFontFromMemory(
			".ttf",
			raw_data(data),
			i32(len(data)),
			pixels,
			raw_data(codepoints[:]),
			i32(len(codepoints)),
		)
		assert(
			rl.IsFontValid(font) &&
			font.texture.id != 0 &&
			font.texture.id != rl.GetFontDefault().texture.id,
			"Inter failed to load",
		)
		assert(font.baseSize == pixels)
		rl.SetTextureFilter(font.texture, .POINT)
		type.fonts[role] = font
	}
	type.density = density
}

text :: proc(
	type: ^Typography,
	role: Type,
	value: cstring,
	x, y: f32,
	color := INK,
	centered := false,
) {
	font := type.fonts[role]
	size := f32(font.baseSize) / type.density
	position := rl.Vector2{x, y}
	if centered {position.x -= rl.MeasureTextEx(font, value, size, 0).x / 2}
	// Match glyph texels to framebuffer pixels; coverage is already antialiased.
	position.x = math.round(position.x * type.density) / type.density
	position.y = math.round(position.y * type.density) / type.density
	rl.DrawTextEx(font, value, position, size, 0, color)
}

main :: proc() {
	smoke := len(os.args) == 2 && os.args[1] == "--smoke-test"
	if len(os.args) > 1 && !smoke {
		fmt.eprintln("Usage: museum [--smoke-test]")
		os.exit(1)
	}

	rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_HIGHDPI, .WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1440, 900, "FORM - an Odin + Raylib museum")
	assert(rl.IsWindowReady(), "Window initialization failed")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(1100, 720)
	rl.SetTargetFPS(165)

	samples: i32
	glGetIntegerv(0x80A9, &samples) // GL_SAMPLES, on the default framebuffer.
	fmt.printf("Default framebuffer: %d MSAA samples\n", samples)
	if samples < 4 {fmt.eprintln("Warning: the driver did not provide the requested 4x MSAA.")}
	if smoke {assert(samples >= 4, "4x MSAA unavailable")}

	type: Typography
	defer for font in type.fonts {rl.UnloadFont(font)}

	renderer := load_renderer()
	defer unload_renderer(&renderer)

	models := [?]rl.Model {
		rl.LoadModelFromMesh(rl.GenMeshCube(1.45, 1.45, 1.45)),
		rl.LoadModelFromMesh(rl.GenMeshSphere(0.88, 40, 64)),
		rl.LoadModelFromMesh(rl.GenMeshTorus(0.28, 1.0, 48, 64)),
		rl.LoadModelFromMesh(rl.GenMeshCube(1, 1, 1)),
	}
	for model in models {assert(rl.IsModelValid(model))}
	defer for model in models {rl.UnloadModel(model)}

	names := [?]cstring{"01 / The cube", "02 / The sphere", "03 / The torus"}
	notes := [?]cstring {
		"Planes, edges, precision.",
		"A continuous surface.",
		"A study in negative space.",
	}

	yaw, pitch, zoom: f32 = 0.18, 0.40, 10.8
	angle: f32
	paused := false
	dragging := false
	effects := Effects{true, true, true}
	baseline: rl.Image
	defer if baseline.data != nil {rl.UnloadImage(baseline)}
	frame := 0
	for !rl.WindowShouldClose() {
		frame += 1
		if smoke {
			effects = Effects{true, true, true}
			switch frame {
			case 5:
				effects = {}
			case 6:
				effects = {
					shadows = true,
				}
			case 7:
				effects = {
					contact = true,
				}
			case 8:
				effects = {
					ssao = true,
				}
			case 15:
				yaw, pitch, angle = -0.45, 0.6, 35
			}
		}
		width, height := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
		if width <= 0 || height <= 0 {continue}
		density := f32(rl.GetRenderHeight()) / height
		refresh_type(&type, density)
		if rl.IsKeyPressed(.SPACE) {paused = !paused}
		if rl.IsKeyPressed(.ONE) {effects.shadows = !effects.shadows}
		if rl.IsKeyPressed(.TWO) {effects.contact = !effects.contact}
		if rl.IsKeyPressed(.THREE) {effects.ssao = !effects.ssao}
		if rl.IsKeyPressed(.R) {
			yaw, pitch, zoom = 0.18, 0.40, 10.8
			angle = 0
		}
		mouse := rl.GetMousePosition()
		in_gallery := mouse.y > 186 && mouse.y < height - 210
		if rl.IsMouseButtonPressed(.LEFT) && in_gallery {dragging = true}
		if !rl.IsMouseButtonDown(.LEFT) || !rl.IsWindowFocused() {dragging = false}
		if dragging {
			delta := rl.GetMouseDelta()
			yaw -= delta.x * 0.005
			pitch += delta.y * 0.004
		}
		dt := min(rl.GetFrameTime(), 0.05)
		if rl.IsKeyDown(.LEFT) {yaw -= dt * 0.7}
		if rl.IsKeyDown(.RIGHT) {yaw += dt * 0.7}
		if rl.IsKeyDown(.UP) {pitch += dt * 0.5}
		if rl.IsKeyDown(.DOWN) {pitch -= dt * 0.5}
		pitch = clamp(pitch, f32(0.22), f32(0.72))
		yaw = clamp(yaw, f32(-0.65), f32(0.65))
		if in_gallery {zoom = clamp(zoom - rl.GetMouseWheelMove() * 0.5, f32(8.8), f32(14.0))}
		if !paused && !smoke {angle += dt * 12}

		camera := rl.Camera3D {
			position   = {
				16 * math.sin(yaw) * math.cos(pitch),
				0.65 + 16 * math.sin(pitch),
				16 * math.cos(yaw) * math.cos(pitch),
			},
			target     = {0, 0.65, 0},
			up         = {0, 1, 0},
			fovy       = zoom * height / (height - 396) * (504.0 / 900.0),
			projection = .ORTHOGRAPHIC,
		}

		rl.BeginDrawing()
		rl.ClearBackground(PAPER)
		render_exhibition(&renderer, models[:], camera, angle, effects)

		for i in 0 ..< 3 {
			anchor := rl.GetWorldToScreen({f32(i - 1) * 3.6, 0, 1.65}, camera)
			label_y := clamp(anchor.y + 20, f32(210), height - 280)
			rl.DrawRectangleRounded({anchor.x - 100, label_y - 8, 200, 65}, 0.12, 8, PAPER)
			text(&type, .Label, names[i], anchor.x, label_y, INK, true)
			text(&type, .Small, notes[i], anchor.x, label_y + 25, MUTED, true)
		}

		rl.DrawRectangle(0, 0, i32(width), 186, PAPER)
		rl.DrawCircleV({45, 42}, 5, TEAL)
		text(&type, .Label, "F O R M   /   0 0 1", 62, 32)
		text(&type, .Title, "A study in form.", 40, 66)
		text(
			&type,
			.Body,
			"Three objects. One typeface. A quieter kind of sample scene.",
			42,
			133,
			MUTED,
		)
		text(&type, .Small, "THE RENDERING ROOM", width - 330, 34, MUTED)
		text(&type, .Label, "Odin + Raylib 6.0", width - 330, 61)
		msaa_text: cstring =
			"4x MSAA / direct framebuffer" if samples >= 4 else "MSAA unavailable / check driver"
		text(&type, .Small, msaa_text, width - 330, 91, TEAL if samples >= 4 else INK)
		text(&type, .Small, "Inter / pixel-matched font atlases", width - 330, 116, MUTED)
		status := rl.TextFormat(
			"1 shadows %s / 2 contact %s / 3 SSAO %s",
			"on" if effects.shadows else "off",
			"on" if effects.contact else "off",
			"on" if effects.ssao else "off",
		)
		text(&type, .Small, status, width - 330, 140, MUTED)
		rl.DrawLineEx({40, 176}, {width - 40, 176}, 1, RULE)

		footer := height - 210
		rl.DrawRectangle(0, i32(footer), i32(width), 210, PAPER)
		rl.DrawLineEx({40, footer}, {width - 40, footer}, 1, RULE)
		text(&type, .Small, "TYPE SPECIMEN / INTER", 40, footer + 19, MUTED)
		text(&type, .Heading, "Good type, real pixels.", 40, footer + 44)
		text(&type, .Body, "Regular + Semibold / 14, 18, 24, 32, 48 px", 42, footer + 93, MUTED)
		column := max(f32(550), width * 0.48)
		text(&type, .Subtitle, "Aa Bb Cc / 0123456789", column, footer + 42)
		text(&type, .Body, "The quick brown fox jumps over the lazy dog.", column, footer + 80)
		text(
			&type,
			.Small,
			"Café, façade, naïve.  ! ? @ # % & ( ) + =",
			column,
			footer + 111,
			MUTED,
		)
		rl.DrawLineEx({40, height - 54}, {width - 40, height - 54}, 1, RULE)
		text(
			&type,
			.Small,
			"Drag / arrows: orbit     Scroll: zoom     Space: pause     R: reset     F12: capture",
			40,
			height - 34,
			MUTED,
		)
		text(
			&type,
			.Small,
			"PAUSED" if paused else "LIVE EXHIBITION",
			width - 174,
			height - 34,
			TEAL,
		)

		if rl.IsKeyPressed(.F12) {
			rgl.DrawRenderBatchActive()
			rl.TakeScreenshot("museum.png")
		}
		if smoke && ((frame >= 4 && frame <= 8) || frame == 14 || frame == 15) {
			for role in Type {
				font := type.fonts[role]
				assert(rl.MeasureTextEx(font, "Inter 0123", f32(font.baseSize), 0).x > 0)
				glyph := rl.GetGlyphInfo(font, 'é')
				assert(glyph.value == 'é', "Latin-1 glyph missing")
			}
			path: cstring
			switch frame {
			case 4:
				path = "_smoke-large.png"
			case 5:
				path = "_smoke-none.png"
			case 6:
				path = "_smoke-shadows.png"
			case 7:
				path = "_smoke-contact.png"
			case 8:
				path = "_smoke-ssao.png"
			case 14:
				path = "_smoke-small.png"
			case 15:
				path = "_smoke-orbit.png"
			}
			rgl.DrawRenderBatchActive()
			rl.TakeScreenshot(path)
			image := rl.LoadImage(path)
			assert(rl.IsImageValid(image))
			assert(image.width == rl.GetRenderWidth() && image.height == rl.GetRenderHeight())
			assert(
				rl.GetImageColor(image, i32(45 * density), i32(42 * density)) == TEAL,
				"2D overlay not rendered",
			)
			if frame == 5 {
				baseline = image
			} else {
				if frame >= 6 && frame <= 8 {
					darker := 0
					for y in i32(186 * density) ..< i32((height - 210) * density) {
						for x in 0 ..< image.width {
							before := rl.GetImageColor(baseline, x, y)
							after := rl.GetImageColor(image, x, y)
							if int(before.r) +
								   int(before.g) +
								   int(before.b) -
								   int(after.r) -
								   int(after.g) -
								   int(after.b) >
							   9 {darker += 1}
						}
					}
					fmt.printf("%s: %d shaded pixels\n", path, darker)
					assert(darker > 100, "Effect did not visibly shade the scene")
				}
				rl.UnloadImage(image)
			}
			assert(
				renderer.width == rl.GetRenderWidth() && renderer.height == rl.GetRenderHeight(),
				"Stale effect target dimensions",
			)
			if frame == 8 {
				images := [2]rl.Image{
					rl.LoadImageFromTexture(renderer.ao_raw.texture),
					rl.LoadImageFromTexture(renderer.ao_blurred.texture),
				}
				variation: [2]i64
				for ao_image, i in images {
					assert(rl.IsImageValid(ao_image), "AO readback failed")
					for y in 1 ..< ao_image.height {
						for x in 1 ..< ao_image.width {
							value := i32(rl.GetImageColor(ao_image, x, y).r)
							left := i32(rl.GetImageColor(ao_image, x - 1, y).r)
							above := i32(rl.GetImageColor(ao_image, x, y - 1).r)
							variation[i] += i64(abs(value - left) + abs(value - above))
						}
					}
					assert(rl.GetImageColor(ao_image, 0, 0) == rl.WHITE, "AO darkened the background")
					rl.UnloadImage(ao_image)
				}
				fmt.printf("AO neighbor variation: raw %d, filtered %d\n", variation[0], variation[1])
				assert(variation[1] < variation[0], "AO filter did not reduce noise")
			}
			current_samples: i32
			glGetIntegerv(0x80A9, &current_samples)
			assert(current_samples >= 4, "Final scene lost framebuffer MSAA")
			assert(glGetError() == 0, "OpenGL rendering error")
		}
		rl.EndDrawing()
		if smoke && frame == 8 {rl.SetWindowSize(1100, 720)}
		if smoke && frame == 15 {
			assert(rl.GetScreenWidth() == 1100 && rl.GetScreenHeight() == 720, "Resize failed")
			fmt.println(
				"Smoke test passed: MSAA, Inter, shadows, contact AO, SSAO, resize, orbit.",
			)
			break
		}
	}
}
