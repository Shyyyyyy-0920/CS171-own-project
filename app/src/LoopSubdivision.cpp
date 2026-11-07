#include "LoopSubdivision.hpp"

#include <stdexcept>

namespace cs171 {
EdgeKey MakeEdgeKey(unsigned int a, unsigned int b) {
  // TODO:返回一个EdgeKey，较小编号放first，较大编号放second
  if (a > b)
    std::swap(a, b);
  return EdgeKey{a, b};
}

void RecordEdge(EdgeTable &table, unsigned int a, unsigned int b, unsigned int opposite) {
  auto key = MakeEdgeKey(a, b);
  table[key].opposites.push_back(opposite);
}

EdgeTable BuildEdgeTable(MeshData const &mesh) {
  EdgeTable newEdgeTable{};
  for (auto const &triangle : mesh.triangles) {
    auto a = triangle(0);
    auto b = triangle(1);
    auto c = triangle(2);
    RecordEdge(newEdgeTable, a, b, c);
    RecordEdge(newEdgeTable, b, c, a);
    RecordEdge(newEdgeTable, c, a, b);
  }
  return newEdgeTable;
}

NeighborTable BuildVertexNeighbors(usize vertexCount, EdgeTable const &edges) {
  NeighborTable neighbors(vertexCount);
  for (auto const &[edge, info] : edges) {
    auto a = edge.first;
    auto b = edge.second;
    neighbors[a].push_back(b);
    neighbors[b].push_back(a);
  }
  return neighbors;
}

Vec3f<>::AsStorage ComputeEdgePoint(MeshData const &mesh, EdgeKey const &edge, EdgeInfo const &info) {
  auto const &aPosition = mesh.vertices[edge.first].position;
  auto const &bPosition = mesh.vertices[edge.second].position;

  if (info.opposites.size() == 1) {
    return (aPosition + bPosition) / 2.0f;
  } else if (info.opposites.size() == 2) {
    auto cIndex = info.opposites[0];
    auto const &cPosition = mesh.vertices[cIndex].position;
    auto c2Index = info.opposites[1];
    auto const &c2Position = mesh.vertices[c2Index].position;
    return (3 * (aPosition + bPosition) + (cPosition + c2Position)) / 8.0f;
  } else {
    throw std::invalid_argument("Edge must have one or two adjacent faces");
  }
}

MeshData BuildEdgePointVertices(MeshData const &mesh, EdgeTable &edges) {
  MeshData next;
  next.vertices = mesh.vertices;
  for (auto &[edge, info] : edges) {
    auto position = ComputeEdgePoint(mesh, edge, info);
    Vertex vertex{};
    vertex.position = position;
    auto newIndex = static_cast<unsigned int>(next.vertices.size());
    info.newVertexIndex = newIndex;
    next.vertices.push_back(vertex);
  }
  return next;
}

NeighborTable BuildBoundaryNeighbors(usize vertexCount, EdgeTable const &edges) {
  NeighborTable neighbors(vertexCount);
  for (auto const &[edge, info] : edges) {
    if (info.opposites.size() == 1) {
      auto a = edge.first;
      auto b = edge.second;
      neighbors[a].push_back(b);
      neighbors[b].push_back(a);
    }
  }
  return neighbors;
}

Vec3f<>::AsStorage ComputeVertexPoint(
    MeshData const &mesh,
    unsigned int vertexIndex,
    std::vector<unsigned int> const &neighborIndices,
    std::vector<unsigned int> const &boundaryIndices
) {
  auto const &position = mesh.vertices[vertexIndex].position;
  if (boundaryIndices.size() == 2) {
    auto A = boundaryIndices[0];
    auto B = boundaryIndices[1];
    return (6.0f * position + mesh.vertices[A].position + mesh.vertices[B].position) / 8.0f;
  }
  if (boundaryIndices.size() == 0 && neighborIndices.size() == 0)
    return position;
  if (boundaryIndices.size() == 0 && neighborIndices.size() != 0) {
    auto n = neighborIndices.size();
    if (n == 3) {
      return (7.0f * position +
              3 * (mesh.vertices[neighborIndices[0]].position + mesh.vertices[neighborIndices[1]].position +
                   mesh.vertices[neighborIndices[2]].position)) /
             16.0f;
    }
    if (n > 3) {
      Vec3f<>::AsStorage sumPosition{};
      for (int i = 0; i < n; ++i)
        sumPosition += mesh.vertices[neighborIndices[i]].position;
      return (5.0f * position) / 8.0f + 3.0f * sumPosition / (8.0f * n);
    }
  }
  throw std::invalid_argument("not support this situation");
}

void UpdataOldVertexPositions(
    MeshData const &mesh, NeighborTable const &neighbors, NeighborTable const &boundaryNeighbors, MeshData &next
) {
  for (int i = 0; i < mesh.vertices.size(); ++i) {
    auto newPosition = ComputeVertexPoint(mesh, i, neighbors[i], boundaryNeighbors[i]);
    next.vertices[i].position = newPosition;
  }
}

unsigned int GetEdgePointIndex(EdgeTable const &edges, unsigned int a, unsigned int b) {
  auto key = MakeEdgeKey(a, b);
  auto const &info = edges.at(key);
  if (info.newVertexIndex != std::numeric_limits<unsigned int>::max())
    return info.newVertexIndex;
  throw std::invalid_argument("have not handout the arrangement ");
}

void AppendSubdividedTriangle(Vec3u<>::AsStorage const &triangle, EdgeTable const &edges, MeshData &next) {
  auto a = triangle(0);
  auto b = triangle(1);
  auto c = triangle(2);
  auto x = GetEdgePointIndex(edges, a, b);
  auto y = GetEdgePointIndex(edges, b, c);
  auto z = GetEdgePointIndex(edges, c, a);
  Vec3u<>::AsStorage face1{a, x, z};
  Vec3u<>::AsStorage face2{b, y, x};
  Vec3u<>::AsStorage face3{c, z, y};
  Vec3u<>::AsStorage face4{x, y, z};
  next.triangles.push_back(face1);
  next.triangles.push_back(face2);
  next.triangles.push_back(face3);
  next.triangles.push_back(face4);
}

void BuildSubdividedTriangles(MeshData const &mesh, EdgeTable const &edges, MeshData &next) {
  next.triangles.clear();
  for (auto const &triangle : mesh.triangles)
    AppendSubdividedTriangle(triangle, edges, next);
}

Vec3f<>::AsStorage ComputeFaceNormalVector(MeshData const &mesh, Vec3u<>::AsStorage const &triangle) {
  auto a = mesh.vertices[triangle(0)].position;
  auto b = mesh.vertices[triangle(1)].position;
  auto c = mesh.vertices[triangle(2)].position;
  auto u = b - a;
  auto v = c - a;
  auto nf = u.Cross(v);
  return nf;
}

void RecomputeVertexNormals(MeshData &mesh) {
  for (auto &vertex : mesh.vertices)
    vertex.normal = Vec3f<>::AsStorage{};
  for (auto &triangle : mesh.triangles) {
    auto a = triangle(0);
    auto b = triangle(1);
    auto c = triangle(2);
    auto faceNormal = ComputeFaceNormalVector(mesh, triangle);
    mesh.vertices[a].normal += faceNormal;
    mesh.vertices[b].normal += faceNormal;
    mesh.vertices[c].normal += faceNormal;
  }
  for (auto &vertex : mesh.vertices) {
    auto length = vertex.normal.Norm();
    if (length == 0)
      continue;
    vertex.normal = vertex.normal / length;
  }
}

MeshData SubdivideLoopOnce(MeshData const &mesh) {
  auto edges = BuildEdgeTable(mesh);
  auto vertexCount = mesh.vertices.size();
  auto neighbors = BuildVertexNeighbors(vertexCount, edges);
  auto new_mesh = BuildEdgePointVertices(mesh, edges);
  auto boundaryNeighbors = BuildBoundaryNeighbors(vertexCount, edges);
  UpdataOldVertexPositions(mesh, neighbors, boundaryNeighbors, new_mesh);
  BuildSubdividedTriangles(mesh, edges, new_mesh);
  RecomputeVertexNormals(new_mesh);
  return new_mesh;
}
} // namespace cs171
