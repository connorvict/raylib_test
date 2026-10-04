#version 330

in vec2 fragTexCoord;

uniform sampler2D texture0;
uniform mat4 projection;
uniform mat4 inverseProjection;
uniform float aoRadius;
uniform float aoStrength;

out vec4 finalColor;

const int SAMPLE_COUNT = 32;

vec3 viewPosition(vec2 uv, float depth) {
    vec4 position = inverseProjection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return position.xyz / position.w;
}

void main() {
    ivec2 size = textureSize(texture0, 0);
    ivec2 pixel = clamp(ivec2(fragTexCoord * vec2(size)), ivec2(0), size - 1);
    vec4 geometry = texelFetch(texture0, pixel, 0);
    if (geometry.a >= 1.0 || aoRadius <= 0.0 || aoStrength <= 0.0) {
        finalColor = vec4(1.0);
        return;
    }

    vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
    vec3 position = viewPosition(uv, geometry.a);
    vec3 n = normalize(geometry.xyz);
    vec3 axis = abs(n.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 tangent = normalize(cross(axis, n));
    vec3 bitangent = cross(n, tangent);
    float rotation = 6.28318531 * fract(sin(dot(vec2(pixel), vec2(12.9898, 78.233))) * 43758.5453);
    tangent = tangent * cos(rotation) + bitangent * sin(rotation);
    mat3 tbn = mat3(tangent, cross(n, tangent), n);

    float occlusion = 0.0;
    for (int i = 0; i < SAMPLE_COUNT; ++i) {
        float t = (float(i) + 0.5) / float(SAMPLE_COUNT);
        float z = fract(float(i) * 0.61803399 + 0.5);
        float angle = float(i) * 2.39996323;
        vec3 kernel = vec3(vec2(cos(angle), sin(angle)) * sqrt(1.0 - z * z), z);
        kernel *= mix(0.1, 1.0, t * t);
        vec3 samplePosition = position + tbn * kernel * aoRadius;
        vec4 clip = projection * vec4(samplePosition, 1.0);
        if (clip.w <= 0.0 || abs(clip.z) >= clip.w) continue;
        vec2 sampleUV = clip.xy / clip.w * 0.5 + 0.5;
        if (any(lessThan(sampleUV, vec2(0.0))) || any(greaterThanEqual(sampleUV, vec2(1.0)))) continue;

        ivec2 samplePixel = ivec2(sampleUV * vec2(size));
        float depth = texelFetch(texture0, samplePixel, 0).a;
        if (depth >= 1.0) continue;
        vec2 sampleCenter = (vec2(samplePixel) + 0.5) / vec2(size);
        float surfaceZ = viewPosition(sampleCenter, depth).z;
        float rangeWeight = smoothstep(0.0, 1.0, aoRadius / max(abs(position.z - surfaceZ), 0.0001));
        occlusion += step(samplePosition.z + 0.03, surfaceZ) * rangeWeight;
    }

    float ao = clamp(1.0 - aoStrength * occlusion / float(SAMPLE_COUNT), 0.0, 1.0);
    finalColor = vec4(vec3(ao), 1.0);
}
