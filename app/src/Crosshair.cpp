#include "Crosshair.hpp"

#include <glad/gl.h>

namespace cs171 {
namespace {

struct DrawState {
  GLint vao{}, program{};
  GLfloat pointSize{};
  GLboolean depthTest{glIsEnabled(GL_DEPTH_TEST)};
  GLboolean programPointSize{glIsEnabled(GL_PROGRAM_POINT_SIZE)};

  DrawState() {
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &vao);
    glGetIntegerv(GL_CURRENT_PROGRAM, &program);
    glGetFloatv(GL_POINT_SIZE, &pointSize);
  }

  ~DrawState() noexcept {
    glBindVertexArray(static_cast<GLuint>(vao));
    glUseProgram(static_cast<GLuint>(program));
    glPointSize(pointSize);
    if (depthTest)
      glEnable(GL_DEPTH_TEST);
    else
      glDisable(GL_DEPTH_TEST);
    if (programPointSize)
      glEnable(GL_PROGRAM_POINT_SIZE);
    else
      glDisable(GL_PROGRAM_POINT_SIZE);
  }
};

} // namespace

Crosshair::Crosshair() : shader_{"shaders/Crosshair.vert", "shaders/Crosshair.frag"} {
  glGenVertexArrays(1, &vao_);
}

Crosshair::~Crosshair() noexcept {
  glDeleteVertexArrays(1, &vao_);
}

void Crosshair::Draw() const {
  DrawState restore;
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_PROGRAM_POINT_SIZE);
  shader_.Use();
  glBindVertexArray(vao_);
  glPointSize(3.0F);
  glDrawArrays(GL_POINTS, 0, 1);
}

} // namespace cs171
