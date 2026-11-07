#version 410 core

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;

uniform mat4 view;
uniform mat4 projection;

out vec3 position;
out vec3 normal;

void main() {
  // The models are given in world space, so there is no model matrix.
  position = aPosition;
  normal = aNormal;
  gl_Position = projection * view * vec4(aPosition, 1.0);
}
