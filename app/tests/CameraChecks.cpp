#include "Camera.hpp"

#include <cmath>
#include <iostream>
#include <stdexcept>

using namespace cs171;
using V3 = Vec3f<>::AsStorage;
using V4 = Vec4f<>::AsStorage;
using M4 = Mat4f<>::AsStorage;

namespace {
void Require(bool condition, char const *message) {
  if (!condition) throw std::runtime_error(message);
}
bool Near(float a, float b) { return std::abs(a - b) < 1.0e-4F; }
bool Finite(M4 const &m) {
  for (int row = 0; row < 4; ++row)
    for (int col = 0; col < 4; ++col)
      if (!std::isfinite(m(row, col))) return false;
  return true;
}
V4 Transform(M4 const &m, V3 const &p) {
  V4 result{};
  result = m * Vec{p(0), p(1), p(2), 1.0F};
  return result;
}
} // namespace

int main() {
  try {
    Camera camera;
    V3 center{Vec{2.0F, -1.0F, 4.0F}};
    camera.Frame(center, 2.0F);
    auto eye = camera.Position(), forward = camera.Forward();
    V3 toward = center - eye;
    Require(Near(toward.Dot(forward) / toward.Norm(), 1.0F), "Frame must face the center");
    auto origin = Transform(camera.View(), eye);
    Require(Near(origin(0), 0) && Near(origin(1), 0) && Near(origin(2), 0) && Near(origin(3), 1),
            "View must send the eye to the origin");
    V3 ahead = eye + forward;
    auto viewAhead = Transform(camera.View(), ahead);
    Require(Near(viewAhead(0), 0) && Near(viewAhead(1), 0) && Near(viewAhead(2), -1),
            "View must send a point ahead along negative z");

    camera.Move(1, 0, 0.5F);
    V3 moved = camera.Position() - eye, changedForward = camera.Forward() - forward;
    Require(Near(moved.Norm(), 3) && Near(moved.Dot(forward), 3) && changedForward.Norm() < 1.0e-5F,
            "Forward movement must travel 3 units without changing orientation");
    eye = camera.Position();
    camera.Move(0, 1, 0.5F);
    moved = camera.Position() - eye;
    Require(Near(moved.Norm(), 3) && Near(moved.Dot(forward), 0) && Near(moved(1), 0),
            "Strafing must be horizontal and perpendicular to forward");

    camera.SetAngles(0, 0);
    camera.Look(30, 0);
    Require(camera.Forward()(0) > 0, "Moving the mouse right must turn right");
    camera.SetAngles(0, 0);
    camera.Look(0, -30);
    Require(camera.Forward()(1) > 0, "Moving the mouse up must look up");
    camera.Look(0, -1.0e6F);
    Require(Finite(camera.View()) && Near(camera.Forward().Norm(), 1), "Upper pitch limit must stay valid");
    camera.Look(0, 2.0e6F);
    Require(Finite(camera.View()) && Near(camera.Forward().Norm(), 1), "Lower pitch limit must stay valid");

    camera.Frame(V3{}, 1.0F);
    auto projection = camera.Projection(1.5F);
    auto nearPoint = Transform(projection, V3{Vec{0.0F, 0.0F, -0.001F}});
    auto farPoint = Transform(projection, V3{Vec{0.0F, 0.0F, -1000.0F}});
    Require(nearPoint(3) > 0 && farPoint(3) > 0 && Near(nearPoint(2) / nearPoint(3), -1)
                && Near(farPoint(2) / farPoint(3), 1), "Projection must map the clip planes after perspective divide");
    camera.Move(1, 1, 100);
    auto afterMove = camera.Projection(1.5F);
    for (int row = 0; row < 4; ++row)
      for (int col = 0; col < 4; ++col)
        Require(Near(projection(row, col), afterMove(row, col)), "Free movement must not change clipping");
    std::cout << "Camera checks passed\n";
    return 0;
  } catch (std::exception const &error) {
    std::cerr << "Camera checks failed: " << error.what() << '\n';
    return 1;
  }
}
