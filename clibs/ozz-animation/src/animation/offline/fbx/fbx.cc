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

#include "ozz/animation/offline/fbx/fbx.h"
#include "ozz/animation/offline/fbx/fbx_base.h"

#include "animation/offline/fbx/fbx_animation.h"
#include "animation/offline/fbx/fbx_skeleton.h"

#include "ozz/base/log.h"

#include "ozz/animation/offline/raw_animation.h"
#include "ozz/animation/offline/raw_skeleton.h"

namespace ozz {
namespace animation {
namespace offline {
namespace fbx {

bool ImportFromFile(const char* _filename, RawSkeleton* _skeleton) {
  if (!_skeleton) {
    return false;
  }
  // Reset skeleton.
  *_skeleton = RawSkeleton();

  // Import Fbx content.
  FbxManagerInstance fbx_manager;
  FbxSkeletonIOSettings settings(fbx_manager);
  FbxSceneLoader scene_loader(_filename, "", fbx_manager, settings);
  if (!scene_loader.scene()) {
    ozz::log::Err() << "Failed to import file " << _filename << "."
                    << std::endl;
    return false;
  }

  if (!ExtractSkeleton(scene_loader, _skeleton)) {
    log::Err() << "Fbx skeleton extraction failed." << std::endl;
    return false;
  }

  return true;
}

bool ImportFromFile(const char* _filename, const Skeleton& _skeleton,
                    float _sampling_rate, Animations* _animations) {
  if (!_animations) {
    return false;
  }
  // Reset animation.
  _animations->clear();

  // Import Fbx content.
  FbxManagerInstance fbx_manager;
  FbxAnimationIOSettings settings(fbx_manager);
  FbxSceneLoader scene_loader(_filename, "", fbx_manager, settings);
  if (!scene_loader.scene()) {
    ozz::log::Err() << "Failed to import file " << _filename << "."
                    << std::endl;
    return false;
  }

  if (!ExtractAnimations(&scene_loader, _skeleton, _sampling_rate,
                         _animations)) {
    log::Err() << "Fbx animation extraction failed." << std::endl;
    return false;
  }

  return true;
}
}  // namespace fbx
}  // namespace offline
}  // namespace animation
}  // namespace ozz
