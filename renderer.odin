package museum

import "core:math"
import rl "vendor:raylib"
import rgl "vendor:raylib/rlgl"

SHADOW_SIZE :: 2048
SHADOW_BIAS :: f32(0.0006)
AO_RADIUS :: f32(0.65)
AO_STRENGTH :: f32(1.0)

Effects :: struct {
	shadows, contact, ssao: bool,
}

Renderer :: struct {
	lit, shadow, geometry, ssao, blur: rl.Shader,
	shadow_map, normal_depth, ao_raw, ao_blurred: rl.RenderTexture2D,
	width, height: i32,
	light_vp: rl.Matrix,
}

load_effect_shader :: proc(vertex, fragment: cstring) -> rl.Shader {
	shader := rl.LoadShaderFromMemory(vertex, fragment)
	assert(rl.IsShaderValid(shader) && shader.id != rgl.GetShaderIdDefault(), "Effect shader failed to compile")
	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(shader, "matModel")
	shader.locs[rl.ShaderLocationIndex.MATRIX_NORMAL] = rl.GetShaderLocation(shader, "matNormal")
	shader.locs[rl.ShaderLocationIndex.MATRIX_VIEW] = rl.GetShaderLocation(shader, "matView")
	shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = rl.GetShaderLocation(shader, "texture0")
	shader.locs[rl.ShaderLocationIndex.MAP_METALNESS] = rl.GetShaderLocation(shader, "texture1")
	shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader, "texture2")
	return shader
}

load_effect_target :: proc(width, height: i32, floating := false) -> rl.RenderTexture2D {
	target := rl.LoadRenderTexture(width, height)
	assert(rl.IsRenderTextureValid(target), "Effect framebuffer allocation failed")
	if floating {
		rl.UnloadTexture(target.texture)
		target.texture.format = .UNCOMPRESSED_R32G32B32A32
		target.texture.id = rgl.LoadTexture(nil, width, height, i32(target.texture.format), 1)
		rgl.FramebufferAttach(target.id, target.texture.id, i32(rgl.FramebufferAttachType.COLOR_CHANNEL0), i32(rgl.FramebufferAttachTextureType.TEXTURE2D), 0)
	}
	assert(target.texture.id != 0 && rgl.FramebufferComplete(target.id), "Effect framebuffer is incomplete")
	rl.SetTextureFilter(target.texture, .POINT)
	rl.SetTextureWrap(target.texture, .CLAMP)
	return target
}

load_renderer :: proc() -> Renderer {
	vertex := cstring(#load("assets/shaders/mesh.vert", string) + "\x00")
	return Renderer{
		lit = load_effect_shader(vertex, cstring(#load("assets/shaders/lit.frag", string) + "\x00")),
		shadow = load_effect_shader(vertex, cstring(#load("assets/shaders/shadow.frag", string) + "\x00")),
		geometry = load_effect_shader(vertex, cstring(#load("assets/shaders/geometry.frag", string) + "\x00")),
		ssao = load_effect_shader(nil, cstring(#load("assets/shaders/ssao.frag", string) + "\x00")),
		blur = load_effect_shader(nil, cstring(#load("assets/shaders/blur.frag", string) + "\x00")),
		shadow_map = load_effect_target(SHADOW_SIZE, SHADOW_SIZE),
	}
}

unload_renderer :: proc(renderer: ^Renderer) {
	for target in ([?]rl.RenderTexture2D{renderer.shadow_map, renderer.normal_depth, renderer.ao_raw, renderer.ao_blurred}) {
		if target.id != 0 {rl.UnloadRenderTexture(target)}
	}
	for shader in ([?]rl.Shader{renderer.lit, renderer.shadow, renderer.geometry, renderer.ssao, renderer.blur}) {
		rl.UnloadShader(shader)
	}
}

resize_effect_targets :: proc(renderer: ^Renderer, width, height: i32) {
	if renderer.width == width && renderer.height == height {return}
	for target in ([?]rl.RenderTexture2D{renderer.normal_depth, renderer.ao_raw, renderer.ao_blurred}) {
		if target.id != 0 {rl.UnloadRenderTexture(target)}
	}
	// ponytail: half-resolution SSAO; increase resolution if fine detail needs it.
	w, h := max((width + 1) / 2, 1), max((height + 1) / 2, 1)
	renderer.normal_depth = load_effect_target(w, h, true)
	renderer.ao_raw = load_effect_target(w, h)
	renderer.ao_blurred = load_effect_target(w, h)
	renderer.width, renderer.height = width, height
}

set_float :: proc(shader: rl.Shader, name: cstring, value: f32) {
	v := value
	rl.SetShaderValue(shader, rl.GetShaderLocation(shader, name), &v, .FLOAT)
}

set_matrix :: proc(shader: rl.Shader, name: cstring, value: rl.Matrix) {
	rl.SetShaderValueMatrix(shader, rl.GetShaderLocation(shader, name), value)
}

draw_exhibits :: proc(models: []rl.Model, shader: rl.Shader, angle: f32, textures := [3]rl.Texture2D{}) {
	for &model in models {
		material := &model.materials[0]
		material.shader = shader
		for texture, i in textures {material.maps[i].texture = texture}
	}
	colors := [?]rl.Color{TEAL, {205, 115, 78, 255}, {192, 156, 66, 255}}
	rl.DrawModelEx(models[3], {0, -0.16, 0}, {0, 1, 0}, 0, {12, 0.30, 5.4}, {231, 232, 223, 255})
	for i in 0..<3 {
		x := f32(i - 1) * 3.6
		rl.DrawModelEx(models[3], {x, 0.55, 0}, {0, 1, 0}, 0, {2.05, 1.1, 2.05}, {250, 249, 244, 255})
		position := rl.Vector3{x, 1.825, 0}
		axis := rl.Vector3{0, 1, 0}
		rotation := angle + 24
		if i == 1 {position.y = 1.98}
		if i == 2 {
			axis = {1, 0, 0}
			rotation = -18 + 8 * math.sin(angle * math.PI / 180)
			position.y = 1.73
		}
		rl.DrawModelEx(models[i], position, axis, rotation, {1, 1, 1}, colors[i])
	}
	// The renderer owns these textures, not the model materials.
	for &model in models {
		for i in 0..<3 {model.materials[0].maps[i].texture = {}}
	}
}

render_exhibition :: proc(renderer: ^Renderer, models: []rl.Model, camera: rl.Camera3D, angle: f32, effects: Effects) {
	resize_effect_targets(renderer, rl.GetRenderWidth(), rl.GetRenderHeight())
	if effects.shadows {
		light_camera := rl.Camera3D{
			position = {-12, 20, 16}, target = {0, 0, 0}, up = {0, 1, 0},
			fovy = 18, projection = .ORTHOGRAPHIC,
		}
		rl.BeginTextureMode(renderer.shadow_map)
		rl.ClearBackground(rl.WHITE)
		rl.BeginMode3D(light_camera)
		rgl.SetMatrixProjection(rl.MatrixOrtho(-9, 9, -9, 9, 0.1, 40))
		renderer.light_vp = rgl.GetMatrixProjection() * rgl.GetMatrixModelview()
		rgl.DisableColorBlend()
		draw_exhibits(models, renderer.shadow, angle)
		rl.EndMode3D()
		rgl.EnableColorBlend()
		rl.EndTextureMode()
	}

	if effects.ssao {
		rl.BeginTextureMode(renderer.normal_depth)
		rl.ClearBackground(rl.WHITE)
		rl.BeginMode3D(camera)
		projection := rgl.GetMatrixProjection()
		inverse_projection := rl.MatrixInvert(projection)
		rgl.DisableColorBlend()
		draw_exhibits(models, renderer.geometry, angle)
		rl.EndMode3D()
		rgl.EnableColorBlend()
		rl.EndTextureMode()

		set_matrix(renderer.ssao, "projection", projection)
		set_matrix(renderer.ssao, "inverseProjection", inverse_projection)
		set_float(renderer.ssao, "aoRadius", AO_RADIUS)
		set_float(renderer.ssao, "aoStrength", AO_STRENGTH)
		rl.BeginTextureMode(renderer.ao_raw)
		rl.ClearBackground(rl.WHITE)
		rl.BeginShaderMode(renderer.ssao)
		rl.DrawTextureRec(renderer.normal_depth.texture, {0, 0, f32(renderer.normal_depth.texture.width), -f32(renderer.normal_depth.texture.height)}, {0, 0}, rl.WHITE)
		rl.EndShaderMode()
		rl.EndTextureMode()

		set_matrix(renderer.blur, "inverseProjection", inverse_projection)
		set_float(renderer.blur, "aoRadius", AO_RADIUS)
		rl.BeginTextureMode(renderer.ao_blurred)
		rl.ClearBackground(rl.WHITE)
		rl.BeginShaderMode(renderer.blur)
		rl.SetShaderValueTexture(renderer.blur, rl.GetShaderLocation(renderer.blur, "texture1"), renderer.normal_depth.texture)
		rl.DrawTextureRec(renderer.ao_raw.texture, {0, 0, f32(renderer.ao_raw.texture.width), -f32(renderer.ao_raw.texture.height)}, {0, 0}, rl.WHITE)
		rl.EndShaderMode()
		rl.EndTextureMode()
	}

	set_matrix(renderer.lit, "lightVP", renderer.light_vp)
	set_float(renderer.lit, "shadowBias", SHADOW_BIAS)
	set_float(renderer.lit, "shadowsEnabled", 1 if effects.shadows else 0)
	set_float(renderer.lit, "contactEnabled", 1 if effects.contact else 0)
	set_float(renderer.lit, "ssaoEnabled", 1 if effects.ssao else 0)
	size := rl.Vector2{f32(renderer.width), f32(renderer.height)}
	texel := rl.Vector2{1.0 / SHADOW_SIZE, 1.0 / SHADOW_SIZE}
	rl.SetShaderValue(renderer.lit, rl.GetShaderLocation(renderer.lit, "renderSize"), &size, .VEC2)
	rl.SetShaderValue(renderer.lit, rl.GetShaderLocation(renderer.lit, "shadowTexel"), &texel, .VEC2)

	rl.BeginMode3D(camera)
	draw_exhibits(models, renderer.lit, angle, {renderer.shadow_map.texture, renderer.normal_depth.texture, renderer.ao_blurred.texture})
	for i in -5..=5 {
		rl.DrawLine3D({f32(i), 0.002, -2.6}, {f32(i), 0.002, 2.6}, {212, 216, 206, 255})
	}
	for i in -2..=2 {
		rl.DrawLine3D({-5.9, 0.002, f32(i)}, {5.9, 0.002, f32(i)}, {212, 216, 206, 255})
	}
	rl.EndMode3D()
}
