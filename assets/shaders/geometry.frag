#version 330

in vec3 viewNormal;

out vec4 finalColor;

void main() {
    finalColor = vec4(normalize(viewNormal), gl_FragCoord.z);
}
