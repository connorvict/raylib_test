#version 330

out vec4 finalColor;

void main() {
    float depth = min(gl_FragCoord.z, 1.0 - 1.0 / 16581375.0);
    vec4 encoded = fract(depth * vec4(1.0, 255.0, 65025.0, 16581375.0));
    encoded -= encoded.yzww * vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
    finalColor = encoded;
}
