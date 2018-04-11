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

#define OZZ_INCLUDE_PRIVATE_HEADER  // Allows to include private headers.

#include "animation/offline/fbx/fbx_skeleton.h"

#include "ozz/animation/offline/raw_skeleton.h"

#include "ozz/base/log.h"

namespace ozz {
namespace animation {
namespace offline {
namespace fbx {

namespace {

enum RecurseReturn { kError, kSkeletonFound, kNoSkeleton };

RecurseReturn RecurseNode(FbxNode* _node, FbxSystemConverter* _converter,
                          RawSkeleton* _skeleton, RawSkeleton::Joint* _parent,
                          int _depth) {
  bool skeleton_found = false;
  RawSkeleton::Joint* this_joint = NULL;

  bool process_node = false;

  // Push this node if it's below a skeleton root (aka has a parent).
  process_node |= _parent != NULL;

  // Push this node as a new joint if it has a joint compatible attribute.
  FbxNodeAttribute* node_attribute = _node->GetNodeAttribute();
  process_node |= node_attribute && node_attribute->GetAttributeType() ==
                                        FbxNodeAttribute::eSkeleton;

  // Process node if required.
  if (process_node) {
    skeleton_found = true;

    RawSkeleton::Joint::Children* sibling = NULL;
    if (_parent) {
      sibling = &_parent->children;
    } else {
      sibling = &_skeleton->roots;
    }

    // Adds a new child.
    sibling->resize(sibling->size() + 1);
    this_joint = &sibling->back();  // Will not be resized inside recursion.
    this_joint->name = _node->GetName();

    // Outputs hierarchy on verbose stream.
    for (int i = 0; i < _depth; ++i) {
      ozz::log::LogV() << '.';
    }
    ozz::log::LogV() << this_joint->name.c_str() << std::endl;

    // Extract bind pose.
    const FbxAMatrix matrix = _parent ? _node->EvaluateLocalTransform()
                                      : _node->EvaluateGlobalTransform();
    if (!_converter->ConvertTransform(matrix, &this_joint->transform)) {
      ozz::log::Err() << "Failed to extract skeleton transform for joint \""
                      << this_joint->name << "\"." << std::endl;
      return kError;
    }

    // One level deeper in the hierarchy.
    _depth++;
  }

  // Iterate node's children.
  for (int i = 0; i < _node->GetChildCount(); i++) {
    FbxNode* child = _node->GetChild(i);
    const RecurseReturn ret =
        RecurseNode(child, _converter, _skeleton, this_joint, _depth);
    if (ret == kError) {
      return ret;
    }
    skeleton_found |= (ret == kSkeletonFound);
  }

  return skeleton_found ? kSkeletonFound : kNoSkeleton;
}
}  // namespace

bool ExtractSkeleton(FbxSceneLoader& _loader, RawSkeleton* _skeleton) {
  RecurseReturn ret = RecurseNode(_loader.scene()->GetRootNode(),
                                  _loader.converter(), _skeleton, NULL, 0);
  if (ret == kNoSkeleton) {
    ozz::log::Err() << "No skeleton found in Fbx scene." << std::endl;
    return false;
  } else if (ret == kError) {
    ozz::log::Err() << "Failed to extract skeleton." << std::endl;
    return false;
  }
  return true;
}
}  // namespace fbx
}  // namespace offline
}  // namespace animation
}  // namespace ozz
