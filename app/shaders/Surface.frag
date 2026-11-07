#version 410 core

in vec3 position;
in vec3 normal;

// 1: show the normal as a color, 0: Blinn-Phong shading.
uniform int normalColor;
uniform vec3 cameraPosition;

out vec4 fragColor;

void main() {
  vec3 n = normalize(normal);

  // Maps every component of the unit normal from [-1, 1] to [0, 1].
  // The normal is NOT flipped for back faces here, so that wrong normals stay visible.
  if (normalColor == 1) {
    fragColor = vec4(n * 0.5 + 0.5, 1.0);
    return;
  }

  // Two-sided Blinn-Phong shading with a light at the camera.
  // Back faces get a different color, which reveals triangles with the wrong winding order.
  if (!gl_FrontFacing)
    n = -n;
  vec3 albedo = gl_FrontFacing ? vec3(0.9, 0.6, 0.35) : vec3(0.35, 0.55, 0.9);
  vec3 l = normalize(cameraPosition - position);
  vec3 h = l; // The light and the viewer are at the same place.
  float diffuse = max(dot(n, l), 0.0);
  float specular = pow(max(dot(n, h), 0.0), 64.0);
  fragColor = vec4(albedo * (0.15 + 0.85 * diffuse) + vec3(0.25 * specular), 1.0);
}
