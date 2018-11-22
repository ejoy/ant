//----------------------------------------------------------------------------//
//                                                                            //
// ozz-animation is hosted at http://github.com/guillaumeblanc/ozz-animation  //
// and distributed under the MIT License (MIT).                               //
//                                                                            //
// Copyright (c) 2017 Guillaume Blanc                                         //
//                                                                            //
// Permission is hereby granted, free of charge, to any person obtaining a    //
// copy of this software and associated documentation files (the "Software"), //
// to deal in the Software without restriction, including without limitation  //
// the rights to use, copy, modify, merge, publish, distribute, sublicense,   //
// and/or sell copies of the Software, and to permit persons to whom the      //
// Software is furnished to do so, subject to the following conditions:       //
//                                                                            //
// The above copyright notice and this permission notice shall be included in //
// all copies or substantial portions of the Software.                        //
//                                                                            //
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR //
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,   //
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL    //
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER //
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    //
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER        //
// DEALINGS IN THE SOFTWARE.                                                  //
//                                                                            //
//----------------------------------------------------------------------------//

#ifndef OZZ_SAMPLES_FRAMEWORK_MESH_H_
#define OZZ_SAMPLES_FRAMEWORK_MESH_H_

#include "ozz/base/containers/vector.h"
#include "ozz/base/io/archive_traits.h"
#include "ozz/base/platform.h"

#include "ozz/base/maths/simd_math.h"
#include "ozz/base/maths/vec_float.h"

namespace ozz {
namespace sample {

// Defines a mesh with skinning information (joint indices and weights).
// The mesh is subdivided into parts that group vertices according to their
// number of influencing joints. Triangle indices are shared across mesh parts.
struct Mesh {
  Mesh();
  ~Mesh();

  // Number of triangle indices for the mesh.
  int triangle_index_count() const {
    return static_cast<int>(triangle_indices.size());
  }

  // Number of vertices for all mesh parts.
  int vertex_count() const {
    int vertex_count = 0;
    for (size_t i = 0; i < parts.size(); ++i) {
      vertex_count += parts[i].vertex_count();
    }
    return vertex_count;
  }

  // Maximum number of joints influences for all mesh parts.
  int max_influences_count() const {
    int max_influences_count = 0;
    for (size_t i = 0; i < parts.size(); ++i) {
      const int influences_count = parts[i].influences_count();
      max_influences_count = influences_count > max_influences_count
                                 ? influences_count
                                 : max_influences_count;
    }
    return max_influences_count;
  }

  // Test if the mesh has skinning informations.
  bool skinned() const {
    for (size_t i = 0; i < parts.size(); ++i) {
      if (parts[i].influences_count() != 0) {
        return true;
      }
    }
    return false;
  }

  // Returns the number of joints used to skin the mesh.
  int num_joints() const { return static_cast<int>(inverse_bind_poses.size()); }

  // Returns the highest joint number used in the skeleton.
  int highest_joint_index() const {
    // Takes advantage that joint_remaps is sorted.
    return joint_remaps.size() != 0 ? static_cast<int>(joint_remaps.back()) : 0;
  }

  // Defines a portion of the mesh. A mesh is subdivided in sets of vertices
  // with the same number of joint influences.
  struct Part {
    int vertex_count() const { return static_cast<int>(positions.size()) / 3; }

    int influences_count() const {
      const int _vertex_count = vertex_count();
      if (_vertex_count == 0) {
        return 0;
      }
      return static_cast<int>(joint_indices.size()) / _vertex_count;
    }

    typedef ozz::Vector<float>::Std Positions;
    Positions positions;
    enum { kPositionsCpnts = 3 };  // x, y, z components

    typedef ozz::Vector<float>::Std Normals;
    Normals normals;
    enum { kNormalsCpnts = 3 };  // x, y, z components

    typedef ozz::Vector<float>::Std Tangents;
    Tangents tangents;
    enum { kTangentsCpnts = 4 };  // x, y, z, right or left handed.

    typedef ozz::Vector<float>::Std UVs;
    UVs uvs;  // u, v components
    enum { kUVsCpnts = 2 };

    typedef ozz::Vector<uint8_t>::Std Colors;
    Colors colors;
    enum { kColorsCpnts = 4 };  // r, g, b, a components

    typedef ozz::Vector<uint16_t>::Std JointIndices;
    JointIndices joint_indices;  // Stride equals influences_count

    typedef ozz::Vector<float>::Std JointWeights;
    JointWeights joint_weights;  // Stride equals influences_count - 1
  };
  typedef ozz::Vector<Part>::Std Parts;
  Parts parts;

  // Triangles indices. Indices are shared across all parts.
  typedef ozz::Vector<uint16_t>::Std TriangleIndices;
  TriangleIndices triangle_indices;

  // Joints remapping indices. As a skin might be influenced by a part of the
  // skeleton only, joint indices and inverse bind pose matrices are reordered
  // to contain only used ones. Note that this array is sorted.
  typedef ozz::Vector<uint16_t>::Std JointRemaps;
  JointRemaps joint_remaps;

  // Inverse bind-pose matrices. These are only available for skinned meshes.
  typedef ozz::Vector<ozz::math::Float4x4>::Std InversBindPoses;
  InversBindPoses inverse_bind_poses;
};
}  // namespace sample

namespace io {

OZZ_IO_TYPE_TAG("ozz-sample-Mesh-Part", sample::Mesh::Part)
OZZ_IO_TYPE_VERSION(1, sample::Mesh::Part)

template <>
struct Extern<sample::Mesh::Part> {
  static void Save(OArchive& _archive, const sample::Mesh::Part* _parts,
                   size_t _count);
  static void Load(IArchive& _archive, sample::Mesh::Part* _parts,
                   size_t _count, uint32_t _version);
};

OZZ_IO_TYPE_TAG("ozz-sample-Mesh", sample::Mesh)
OZZ_IO_TYPE_VERSION(1, sample::Mesh)

template <>
struct Extern<sample::Mesh> {
  static void Save(OArchive& _archive, const sample::Mesh* _meshes,
                   size_t _count);
  static void Load(IArchive& _archive, sample::Mesh* _meshes, size_t _count,
                   uint32_t _version);
};
}  // namespace io
}  // namespace ozz
#endif  // OZZ_SAMPLES_FRAMEWORK_MESH_H_
