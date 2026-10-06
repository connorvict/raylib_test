package tts

import rl "vendor:raylib"
import rgl "vendor:raylib/rlgl"

SHADOW_SIZE :: 2048
SHADOW_BIAS :: f32(0.0006)
AO_RADIUS :: f32(0.65)
AO_STRENGTH :: f32(1.0)

Render_Effects :: struct {
	shadows, contact_ao, ssao: bool,
}

Renderer :: struct {
	lit_shader, shadow_shader, geometry_shader, ssao_shader, blur_shader: rl.Shader,
	shadow_map, normal_depth, ao_raw, ao_blurred: rl.RenderTexture2D,
	width, height: i32,
}

effect_shader_load :: proc(vertex, fragment: cstring) -> rl.Shader {
	shader := rl.LoadShaderFromMemory(vertex, fragment)
	assert(
		rl.IsShaderValid(shader) && shader.id != rgl.GetShaderIdDefault(),
		"Effect shader failed to compile",
	)

	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(shader, "matModel")
	shader.locs[rl.ShaderLocationIndex.MATRIX_NORMAL] = rl.GetShaderLocation(shader, "matNormal")
	shader.locs[rl.ShaderLocationIndex.MATRIX_VIEW] = rl.GetShaderLocation(shader, "matView")
	shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = rl.GetShaderLocation(shader, "texture0")
	shader.locs[rl.ShaderLocationIndex.MAP_METALNESS] = rl.GetShaderLocation(shader, "texture1")
	shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader, "texture2")
	return shader
}

effect_target_load :: proc(width, height: i32, floating := false) -> rl.RenderTexture2D {
	target := rl.LoadRenderTexture(width, height)
	assert(rl.IsRenderTextureValid(target), "Effect framebuffer allocation failed")

	if floating {
		rl.UnloadTexture(target.texture)
		target.texture.format = .UNCOMPRESSED_R32G32B32A32
		target.texture.id = rgl.LoadTexture(nil, width, height, i32(target.texture.format), 1)
		rgl.FramebufferAttach(
			target.id,
			target.texture.id,
			i32(rgl.FramebufferAttachType.COLOR_CHANNEL0),
			i32(rgl.FramebufferAttachTextureType.TEXTURE2D),
			0,
		)
	}

	assert(
		target.texture.id != 0 && rgl.FramebufferComplete(target.id),
		"Effect framebuffer is incomplete",
	)
	rl.SetTextureFilter(target.texture, .POINT)
	rl.SetTextureWrap(target.texture, .CLAMP)
	return target
}

renderer_load :: proc(lighting_fragment: cstring) -> Renderer {
	vertex := cstring(#load("../assets/shaders/mesh.vert", string) + "\x00")
	return Renderer {
		lit_shader = effect_shader_load(vertex, lighting_fragment),
		shadow_shader = effect_shader_load(vertex, cstring(#load("../assets/shaders/shadow.frag", string) + "\x00")),
		geometry_shader = effect_shader_load(vertex, cstring(#load("../assets/shaders/geometry.frag", string) + "\x00")),
		ssao_shader = effect_shader_load(nil, cstring(#load("../assets/shaders/ssao.frag", string) + "\x00")),
		blur_shader = effect_shader_load(nil, cstring(#load("../assets/shaders/blur.frag", string) + "\x00")),
		shadow_map = effect_target_load(SHADOW_SIZE, SHADOW_SIZE),
	}
}

renderer_unload :: proc(renderer: ^Renderer) {
	targets := [?]rl.RenderTexture2D {
		renderer.shadow_map,
		renderer.normal_depth,
		renderer.ao_raw,
		renderer.ao_blurred,
	}
	for target in targets {
		if target.id != 0 {
			rl.UnloadRenderTexture(target)
		}
	}

	shaders := [?]rl.Shader {
		renderer.lit_shader,
		renderer.shadow_shader,
		renderer.geometry_shader,
		renderer.ssao_shader,
		renderer.blur_shader,
	}
	for shader in shaders {
		rl.UnloadShader(shader)
	}
}

renderer_resize :: proc(renderer: ^Renderer, width, height: i32) {
	if renderer.width == width && renderer.height == height {
		return
	}

	targets := [?]rl.RenderTexture2D {
		renderer.normal_depth,
		renderer.ao_raw,
		renderer.ao_blurred,
	}
	for target in targets {
		if target.id != 0 {
			rl.UnloadRenderTexture(target)
		}
	}

	// Half-resolution targets keep SSAO and blur costs down.
	ao_width := max((width + 1) / 2, 1)
	ao_height := max((height + 1) / 2, 1)
	renderer.normal_depth = effect_target_load(ao_width, ao_height, true)
	renderer.ao_raw = effect_target_load(ao_width, ao_height)
	renderer.ao_blurred = effect_target_load(ao_width, ao_height)
	renderer.width, renderer.height = width, height
}

shader_float_set :: proc(shader: rl.Shader, name: cstring, value: f32) {
	uniform_value := value
	rl.SetShaderValue(shader, rl.GetShaderLocation(shader, name), &uniform_value, .FLOAT)
}

shader_matrix_set :: proc(shader: rl.Shader, name: cstring, value: rl.Matrix) {
	rl.SetShaderValueMatrix(shader, rl.GetShaderLocation(shader, name), value)
}

renderer_ao_render :: proc(renderer: ^Renderer, projection: rl.Matrix) {
	inverse_projection := rl.MatrixInvert(projection)
	shader_matrix_set(renderer.ssao_shader, "projection", projection)
	shader_matrix_set(renderer.ssao_shader, "inverseProjection", inverse_projection)
	shader_float_set(renderer.ssao_shader, "aoRadius", AO_RADIUS)
	shader_float_set(renderer.ssao_shader, "aoStrength", AO_STRENGTH)
	rl.BeginTextureMode(renderer.ao_raw)
	rl.ClearBackground(rl.WHITE)
	rl.BeginShaderMode(renderer.ssao_shader)
	rl.DrawTextureRec(
		renderer.normal_depth.texture,
		{0, 0, f32(renderer.normal_depth.texture.width), -f32(renderer.normal_depth.texture.height)},
		{0, 0},
		rl.WHITE,
	)
	rl.EndShaderMode()
	rl.EndTextureMode()

	shader_matrix_set(renderer.blur_shader, "inverseProjection", inverse_projection)
	shader_float_set(renderer.blur_shader, "aoRadius", AO_RADIUS)
	rl.BeginTextureMode(renderer.ao_blurred)
	rl.ClearBackground(rl.WHITE)
	rl.BeginShaderMode(renderer.blur_shader)
	rl.SetShaderValueTexture(
		renderer.blur_shader,
		rl.GetShaderLocation(renderer.blur_shader, "texture1"),
		renderer.normal_depth.texture,
	)
	rl.DrawTextureRec(
		renderer.ao_raw.texture,
		{0, 0, f32(renderer.ao_raw.texture.width), -f32(renderer.ao_raw.texture.height)},
		{0, 0},
		rl.WHITE,
	)
	rl.EndShaderMode()
	rl.EndTextureMode()
}

renderer_lighting_set :: proc(
	renderer: ^Renderer,
	effects: Render_Effects,
	light_view_projection: rl.Matrix,
) {
	shader_matrix_set(renderer.lit_shader, "lightVP", light_view_projection)
	shader_float_set(renderer.lit_shader, "shadowBias", SHADOW_BIAS)
	shader_float_set(renderer.lit_shader, "shadowsEnabled", 1 if effects.shadows else 0)
	shader_float_set(renderer.lit_shader, "contactEnabled", 1 if effects.contact_ao else 0)
	shader_float_set(renderer.lit_shader, "ssaoEnabled", 1 if effects.ssao else 0)
	render_size := rl.Vector2{f32(renderer.width), f32(renderer.height)}
	shadow_texel := rl.Vector2{1.0 / SHADOW_SIZE, 1.0 / SHADOW_SIZE}
	rl.SetShaderValue(renderer.lit_shader, rl.GetShaderLocation(renderer.lit_shader, "renderSize"), &render_size, .VEC2)
	rl.SetShaderValue(renderer.lit_shader, rl.GetShaderLocation(renderer.lit_shader, "shadowTexel"), &shadow_texel, .VEC2)
}
