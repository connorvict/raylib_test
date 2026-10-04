#version 330

in vec2 fragTexCoord;

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform mat4 inverseProjection;
uniform float aoRadius;

out vec4 finalColor;

vec3 viewPosition(ivec2 pixel, ivec2 size, float depth) {
    vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
    vec4 position = inverseProjection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return position.xyz / position.w;
}

void main() {
    ivec2 size = textureSize(texture1, 0);
    ivec2 pixel = clamp(ivec2(fragTexCoord * vec2(size)), ivec2(0), size - 1);
    vec4 center = texelFetch(texture1, pixel, 0);
    if (center.a >= 1.0) {
        finalColor = vec4(1.0);
        return;
    }

    vec3 n = normalize(center.xyz);
    vec3 centerPosition = viewPosition(pixel, size, center.a);
    float depthSigma = max(aoRadius * 0.1, 0.015);
    float sum = 0.0;
    float weightSum = 0.0;
    for (int y = -3; y <= 3; ++y) {
        for (int x = -3; x <= 3; ++x) {
            ivec2 tap = pixel + ivec2(x, y);
            if (any(lessThan(tap, ivec2(0))) || any(greaterThanEqual(tap, size))) continue;
            vec4 geometry = texelFetch(texture1, tap, 0);
            if (geometry.a >= 1.0) continue;
            vec3 tapNormal = normalize(geometry.xyz);
            float agreement = dot(n, tapNormal);
            vec3 offset = viewPosition(tap, size, geometry.a) - centerPosition;
            float delta = max(abs(dot(offset, n)), abs(dot(offset, tapNormal)));
            if (agreement <= 0.75 || delta > depthSigma * 3.0) continue;

            float spatialWeight = exp(-float(x * x + y * y) / 8.0);
            float depthWeight = exp(-0.5 * delta * delta / (depthSigma * depthSigma));
            float weight = spatialWeight * depthWeight * smoothstep(0.75, 0.95, agreement);
            sum += texelFetch(texture0, tap, 0).r * weight;
            weightSum += weight;
        }
    }

    float ao = sum / max(weightSum, 0.0001);
    finalColor = vec4(vec3(ao), 1.0);
}
