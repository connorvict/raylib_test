#version 330

in vec3 worldPosition;
in vec3 normal;
in vec3 viewNormal;
in vec4 color;

uniform vec4 colDiffuse;
uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform mat4 lightVP;
uniform vec2 renderSize;
uniform vec2 shadowTexel;
uniform float shadowBias;
uniform float shadowsEnabled;
uniform float contactEnabled;
uniform float ssaoEnabled;

out vec4 finalColor;

float unpackDepth(vec4 encoded) {
    return clamp(dot(encoded, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0)), 0.0, 1.0);
}

float shadowVisibility(vec3 n, vec3 lightDirection) {
    vec4 clip = lightVP * vec4(worldPosition, 1.0);
    if (clip.w <= 0.0) return 1.0;
    vec3 coordinate = clip.xyz / clip.w * 0.5 + 0.5;
    if (any(lessThan(coordinate, vec3(0.0))) || any(greaterThan(coordinate, vec3(1.0)))) return 1.0;

    float bias = shadowBias * (1.0 + 3.0 * (1.0 - max(dot(n, lightDirection), 0.0)));
    float visibility = 0.0;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 uv = coordinate.xy + vec2(x, y) * shadowTexel;
            if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
                visibility += 1.0;
            } else {
                visibility += step(coordinate.z - bias, unpackDepth(texture(texture0, uv)));
            }
        }
    }
    return visibility / 9.0;
}

float screenAO() {
    ivec2 size = textureSize(texture1, 0);
    vec2 coordinate = gl_FragCoord.xy / renderSize * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(coordinate));
    vec2 fraction = fract(coordinate);
    vec3 n = normalize(viewNormal);
    float sum = 0.0;
    float weightSum = 0.0;
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 2; ++x) {
            ivec2 tap = base + ivec2(x, y);
            if (any(lessThan(tap, ivec2(0))) || any(greaterThanEqual(tap, size))) continue;
            vec4 geometry = texelFetch(texture1, tap, 0);
            float delta = abs(gl_FragCoord.z - geometry.a);
            if (geometry.a >= 1.0 || delta >= 0.00025) continue;
            float agreement = dot(n, normalize(geometry.xyz));
            if (agreement <= 0.8) continue;

            vec2 bilinear = mix(vec2(1.0) - fraction, fraction, vec2(x, y));
            float weight = bilinear.x * bilinear.y;
            weight *= 1.0 - smoothstep(0.00005, 0.00025, delta);
            weight *= smoothstep(0.8, 0.95, agreement);
            sum += texelFetch(texture2, tap, 0).r * weight;
            weightSum += weight;
        }
    }
    return weightSum > 0.0001 ? sum / weightSum : 1.0;
}

float contactAO() {
    // ponytail: fixed pedestal contacts; use scene geometry if the layout changes.
    float occlusion = 0.0;
    for (int i = 0; i < 3; ++i) {
        vec2 offset = worldPosition.xz - vec2(float(i - 1) * 3.6, 0.0);
        vec2 box = abs(offset) - vec2(1.025);
        float distanceToBox = length(max(box, vec2(0.0)));
        float ground = exp(-distanceToBox * distanceToBox / 0.0625)
                     * exp(-abs(worldPosition.y + 0.01) / 0.12);
        float top = exp(-dot(offset, offset) / 0.5)
                  * exp(-abs(worldPosition.y - 1.1) / 0.1);
        occlusion += 0.34 * ground + 0.28 * top;
    }
    return clamp(1.0 - occlusion, 0.5, 1.0);
}

void main() {
    vec3 n = normalize(normal);
    vec3 lightDirection = normalize(vec3(-0.6, 1.0, 0.8));
    float key = max(dot(n, lightDirection), 0.0);
    float fill = max(dot(n, normalize(vec3(0.8, 0.3, -0.5))), 0.0);
    float visibility = shadowsEnabled > 0.5 ? shadowVisibility(n, lightDirection) : 1.0;
    float ao = ssaoEnabled > 0.5 ? screenAO() : 1.0;
    if (contactEnabled > 0.5) ao *= contactAO();
    vec3 light = vec3(0.48) * ao
               + vec3(0.48, 0.46, 0.42) * key * visibility
               + vec3(0.12, 0.15, 0.18) * fill * mix(1.0, ao, 0.25);
    finalColor = vec4(color.rgb * colDiffuse.rgb * light, color.a * colDiffuse.a);
}
