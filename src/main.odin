package tts

import "core:math"
import rl "vendor:raylib"
import rgl "vendor:raylib/rlgl"

INTER_REGULAR :: #load("../assets/fonts/Inter-Regular.ttf", []u8)
INTER_SEMIBOLD :: #load("../assets/fonts/Inter-SemiBold.ttf", []u8)

PAPER :: rl.Color{247, 246, 242, 255}
INK :: rl.Color{36, 43, 44, 255}
MUTED :: rl.Color{99, 105, 103, 255}
RULE :: rl.Color{215, 216, 208, 255}
TEAL :: rl.Color{42, 119, 117, 255}

Text_Role :: enum {
	Small,
	Body,
	Subtitle,
	Heading,
	Title,
	Label,
}

TEXT_SIZES :: [Text_Role]int {
	.Small    = 14,
	.Body     = 18,
	.Subtitle = 24,
	.Heading  = 32,
	.Title    = 48,
	.Label    = 18,
}

Typography :: struct {
	fonts:   [Text_Role]rl.Font,
	density: f32,
}

typography_refresh :: proc(typography: ^Typography, density: f32) {
	if typography.density == density {
		return
	}

	codepoints: [191]rune
	for &codepoint, i in codepoints {
		codepoint = rune(32 + i) if i < 95 else rune(160 + i - 95)
	}

	sizes := TEXT_SIZES
	for role in Text_Role {
		if typography.density > 0 {
			rl.UnloadFont(typography.fonts[role])
		}

		data := INTER_REGULAR
		if role == .Heading || role == .Title || role == .Label {
			data = INTER_SEMIBOLD
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
		rl.SetTextureFilter(font.texture, .POINT)
		typography.fonts[role] = font
	}

	typography.density = density
}

text_draw :: proc(
	typography: ^Typography,
	role: Text_Role,
	value: cstring,
	x, y: f32,
	color := INK,
	centered := false,
) {
	font := typography.fonts[role]
	size := f32(font.baseSize) / typography.density
	position := rl.Vector2{x, y}
	if centered {
		position.x -= rl.MeasureTextEx(font, value, size, 0).x / 2
	}

	// Match glyph texels to framebuffer pixels; coverage is already antialiased.
	position.x = math.round(position.x * typography.density) / typography.density
	position.y = math.round(position.y * typography.density) / typography.density
	rl.DrawTextEx(font, value, position, size, 0, color)
}

exhibits_draw :: proc(
	models: []rl.Model,
	shader: rl.Shader,
	angle: f32,
	textures := [3]rl.Texture2D{},
) {
	for &model in models {
		material := &model.materials[0]
		material.shader = shader
		for texture, i in textures {
			material.maps[i].texture = texture
		}
	}

	colors := [?]rl.Color{TEAL, {205, 115, 78, 255}, {192, 156, 66, 255}}
	rl.DrawModelEx(models[3], {0, -0.16, 0}, {0, 1, 0}, 0, {12, 0.30, 5.4}, {231, 232, 223, 255})
	for color, i in colors {
		x := f32(i - 1) * 3.6
		rl.DrawModelEx(models[3], {x, 0.55, 0}, {0, 1, 0}, 0, {2.05, 1.1, 2.05}, {250, 249, 244, 255})

		position := rl.Vector3{x, 1.825, 0}
		axis := rl.Vector3{0, 1, 0}
		rotation := angle + 24
		if i == 1 {
			position.y = 1.98
		}
		if i == 2 {
			axis = {1, 0, 0}
			rotation = -18 + 8 * math.sin(angle * math.PI / 180)
			position.y = 1.73
		}
		rl.DrawModelEx(models[i], position, axis, rotation, {1, 1, 1}, color)
	}

	// The renderer owns these textures, not the model materials.
	for &model in models {
		for i in 0 ..< len(textures) {
			model.materials[0].maps[i].texture = {}
		}
	}
}

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_HIGHDPI, .WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1440, 900, "FORM - an Odin + Raylib museum")
	assert(rl.IsWindowReady(), "Window initialization failed")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(1100, 720)
	rl.SetTargetFPS(165)

	typography: Typography
	defer for font in typography.fonts {
		rl.UnloadFont(font)
	}

	lighting_fragment := cstring(#load("../assets/shaders/lit.frag", string) + "\x00")
	renderer := renderer_load(lighting_fragment)
	defer renderer_unload(&renderer)

	models := [?]rl.Model {
		rl.LoadModelFromMesh(rl.GenMeshCube(1.45, 1.45, 1.45)),
		rl.LoadModelFromMesh(rl.GenMeshSphere(0.88, 40, 64)),
		rl.LoadModelFromMesh(rl.GenMeshTorus(0.28, 1.0, 48, 64)),
		rl.LoadModelFromMesh(rl.GenMeshCube(1, 1, 1)),
	}
	for model in models {
		assert(rl.IsModelValid(model))
	}
	defer for model in models {
		rl.UnloadModel(model)
	}

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
	effects := Render_Effects {
		shadows = true,
		contact_ao = true,
		ssao = true,
	}
	light_view_projection: rl.Matrix

	for !rl.WindowShouldClose() {
		width, height := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
		if width <= 0 || height <= 0 {
			continue
		}

		density := f32(rl.GetRenderHeight()) / height
		typography_refresh(&typography, density)

		if rl.IsKeyPressed(.SPACE) {
			paused = !paused
		}
		if rl.IsKeyPressed(.ONE) {
			effects.shadows = !effects.shadows
		}
		if rl.IsKeyPressed(.TWO) {
			effects.contact_ao = !effects.contact_ao
		}
		if rl.IsKeyPressed(.THREE) {
			effects.ssao = !effects.ssao
		}
		if rl.IsKeyPressed(.R) {
			yaw, pitch, zoom = 0.18, 0.40, 10.8
			angle = 0
		}

		mouse := rl.GetMousePosition()
		in_gallery := mouse.y > 186 && mouse.y < height - 210
		if rl.IsMouseButtonPressed(.LEFT) && in_gallery {
			dragging = true
		}
		if !rl.IsMouseButtonDown(.LEFT) || !rl.IsWindowFocused() {
			dragging = false
		}
		if dragging {
			mouse_delta := rl.GetMouseDelta()
			yaw -= mouse_delta.x * 0.005
			pitch += mouse_delta.y * 0.004
		}

		delta_time := min(rl.GetFrameTime(), 0.05)
		if rl.IsKeyDown(.LEFT) {
			yaw -= delta_time * 0.7
		}
		if rl.IsKeyDown(.RIGHT) {
			yaw += delta_time * 0.7
		}
		if rl.IsKeyDown(.UP) {
			pitch += delta_time * 0.5
		}
		if rl.IsKeyDown(.DOWN) {
			pitch -= delta_time * 0.5
		}
		pitch = clamp(pitch, f32(0.22), f32(0.72))
		yaw = clamp(yaw, f32(-0.65), f32(0.65))
		if in_gallery {
			zoom = clamp(zoom - rl.GetMouseWheelMove() * 0.5, f32(8.8), f32(14.0))
		}
		if !paused {
			angle += delta_time * 12
		}

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
		renderer_resize(&renderer, rl.GetRenderWidth(), rl.GetRenderHeight())

		if effects.shadows {
			light_camera := rl.Camera3D {
				position   = {-12, 20, 16},
				target     = {0, 0, 0},
				up         = {0, 1, 0},
				fovy       = 18,
				projection = .ORTHOGRAPHIC,
			}

			rl.BeginTextureMode(renderer.shadow_map)
			rl.ClearBackground(rl.WHITE)
			rl.BeginMode3D(light_camera)
			rgl.SetMatrixProjection(rl.MatrixOrtho(-9, 9, -9, 9, 0.1, 40))
			light_view_projection = rgl.GetMatrixProjection() * rgl.GetMatrixModelview()
			rgl.DisableColorBlend()
			exhibits_draw(models[:], renderer.shadow_shader, angle)
			rl.EndMode3D()
			rgl.EnableColorBlend()
			rl.EndTextureMode()
		}

		if effects.ssao {
			rl.BeginTextureMode(renderer.normal_depth)
			rl.ClearBackground(rl.WHITE)
			rl.BeginMode3D(camera)
			projection := rgl.GetMatrixProjection()
			rgl.DisableColorBlend()
			exhibits_draw(models[:], renderer.geometry_shader, angle)
			rl.EndMode3D()
			rgl.EnableColorBlend()
			rl.EndTextureMode()

			renderer_ao_render(&renderer, projection)
		}

		renderer_lighting_set(&renderer, effects, light_view_projection)
		rl.BeginMode3D(camera)
		exhibits_draw(
			models[:],
			renderer.lit_shader,
			angle,
			{renderer.shadow_map.texture, renderer.normal_depth.texture, renderer.ao_blurred.texture},
		)
		for i in -5 ..= 5 {
			rl.DrawLine3D({f32(i), 0.002, -2.6}, {f32(i), 0.002, 2.6}, {212, 216, 206, 255})
		}
		for i in -2 ..= 2 {
			rl.DrawLine3D({-5.9, 0.002, f32(i)}, {5.9, 0.002, f32(i)}, {212, 216, 206, 255})
		}
		rl.EndMode3D()

		for name, i in names {
			anchor := rl.GetWorldToScreen({f32(i - 1) * 3.6, 0, 1.65}, camera)
			label_y := clamp(anchor.y + 20, f32(210), height - 280)
			rl.DrawRectangleRounded({anchor.x - 100, label_y - 8, 200, 65}, 0.12, 8, PAPER)
			text_draw(&typography, .Label, name, anchor.x, label_y, INK, true)
			text_draw(&typography, .Small, notes[i], anchor.x, label_y + 25, MUTED, true)
		}

		rl.DrawRectangle(0, 0, i32(width), 186, PAPER)
		rl.DrawCircleV({45, 42}, 5, TEAL)
		text_draw(&typography, .Label, "F O R M   /   0 0 1", 62, 32)
		text_draw(&typography, .Title, "A study in form.", 40, 66)
		text_draw(
			&typography,
			.Body,
			"Three objects. One typeface. A quieter kind of sample scene.",
			42,
			133,
			MUTED,
		)
		text_draw(&typography, .Small, "THE RENDERING ROOM", width - 330, 34, MUTED)
		text_draw(&typography, .Label, "Odin + Raylib 6.0", width - 330, 61)
		text_draw(&typography, .Small, "4x MSAA requested / direct framebuffer", width - 330, 91, TEAL)
		text_draw(&typography, .Small, "Inter / pixel-matched font atlases", width - 330, 116, MUTED)
		status := rl.TextFormat(
			"1 shadows %s / 2 contact %s / 3 SSAO %s",
			"on" if effects.shadows else "off",
			"on" if effects.contact_ao else "off",
			"on" if effects.ssao else "off",
		)
		text_draw(&typography, .Small, status, width - 330, 140, MUTED)
		rl.DrawLineEx({40, 176}, {width - 40, 176}, 1, RULE)

		footer_y := height - 210
		rl.DrawRectangle(0, i32(footer_y), i32(width), 210, PAPER)
		rl.DrawLineEx({40, footer_y}, {width - 40, footer_y}, 1, RULE)
		text_draw(&typography, .Small, "TYPE SPECIMEN / INTER", 40, footer_y + 19, MUTED)
		text_draw(&typography, .Heading, "Good type, real pixels.", 40, footer_y + 44)
		text_draw(&typography, .Body, "Regular + Semibold / 14, 18, 24, 32, 48 px", 42, footer_y + 93, MUTED)
		column_x := max(f32(550), width * 0.48)
		text_draw(&typography, .Subtitle, "Aa Bb Cc / 0123456789", column_x, footer_y + 42)
		text_draw(&typography, .Body, "The quick brown fox jumps over the lazy dog.", column_x, footer_y + 80)
		text_draw(
			&typography,
			.Small,
			"Café, façade, naïve.  ! ? @ # % & ( ) + =",
			column_x,
			footer_y + 111,
			MUTED,
		)
		rl.DrawLineEx({40, height - 54}, {width - 40, height - 54}, 1, RULE)
		text_draw(
			&typography,
			.Small,
			"Drag / arrows: orbit     Scroll: zoom     Space: pause     R: reset     F12: capture",
			40,
			height - 34,
			MUTED,
		)
		text_draw(
			&typography,
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
		rl.EndDrawing()
	}
}
