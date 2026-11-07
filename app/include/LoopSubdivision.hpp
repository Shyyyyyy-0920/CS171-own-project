#pragma once
#include "Mesh.hpp"

#include <limits>
#include <map>
#include <utility>
#include <vector>

namespace cs171 {

using EdgeKey = std::pair<unsigned int, unsigned int>;
using NeighborTable = std::vector<std::vector<unsigned int>>;

struct EdgeInfo {
  std::vector<unsigned int> opposites;
  unsigned int newVertexIndex = std::numeric_limits<unsigned int>::max();
};

using EdgeTable = std::map<EdgeKey, EdgeInfo>;

EdgeKey MakeEdgeKey(unsigned int a, unsigned int b);

void RecordEdge(EdgeTable &table, unsigned int a, unsigned int b, unsigned int opposite);

EdgeTable BuildEdgeTable(MeshData const &mesh);

NeighborTable BuildVertexNeighbors(usize vectexCount, EdgeTable const &edges);

Vec3f<>::AsStorage ComputeEdgePoint(MeshData const &mesh, EdgeKey const &edge, EdgeInfo const &info);

MeshData BuildEdgePointVertices(MeshData const &mesh, EdgeTable &edges);

NeighborTable BuildBoundaryNeighbors(usize vertexCount, EdgeTable const &edges);

Vec3f<>::AsStorage ComputeVertexPoint(
    MeshData const &mesh,
    unsigned int vertexIndex,
    std::vector<unsigned int> const &neighborIndices,
    std::vector<unsigned int> const &boundaryIndices
);

void UpdataOldVertexPositions(
    MeshData const &mesh, NeighborTable const &neighbors, NeighborTable const &boundaryNeighbors, MeshData &next
);

unsigned int GetEdgePointIndex(EdgeTable const &edges, unsigned int a, unsigned int b);

void AppendSubdividedTriangle(Vec3u<>::AsStorage const &triangle, EdgeTable const &edges, MeshData &next);

void BuildSubdividedTriangles(MeshData const &mesh, EdgeTable const &edges, MeshData &next);

Vec3f<>::AsStorage ComputeFaceNormalVector(MeshData const &mesh, Vec3u<>::AsStorage const &triangle);

void RecomputeVertexNormals(MeshData &mesh);

MeshData SubdivideLoopOnce(MeshData const &mesh);
} // namespace cs171
