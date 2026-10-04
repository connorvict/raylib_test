#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 matModel;
uniform mat4 matView;
uniform mat4 matNormal;
uniform mat4 mvp;

out vec3 worldPosition;
out vec3 normal;
out vec3 viewNormal;
out vec4 color;

void main() {
    worldPosition = (matModel * vec4(vertexPosition, 1.0)).xyz;
    normal = normalize(mat3(matNormal) * vertexNormal);
    viewNormal = normalize(mat3(matView) * normal);
    color = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
