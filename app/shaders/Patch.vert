#version 410 core

layout(location = 0) in vec3 aPosition;

out vec3 controlPoint;

// Control points are passed through untouched; the tessellation evaluation shader evaluates the surface.
void main() { controlPoint = aPosition; }
