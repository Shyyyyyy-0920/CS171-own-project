#pragma once

#include "Shader.hpp"

namespace cs171 {

/// A fixed green 3-pixel point at the screen center, matching the HW1 HUD.
/// Construct and destroy this object while its OpenGL context is current.
/// In particular, declare it after Window so it is destroyed before Window.
class Crosshair {
public:
  Crosshair();
  ~Crosshair() noexcept;

  Crosshair(Crosshair const &) = delete;
  Crosshair &operator=(Crosshair const &) = delete;

  /// Restores the previous VAO, program, point size and relevant enable states.
  void Draw() const;

private:
  Shader shader_;
  unsigned int vao_{};
};

} // namespace cs171
