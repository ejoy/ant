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

#ifndef OZZ_OZZ_ANIMATION_OFFLINE_FBX_FBX_H_
#define OZZ_OZZ_ANIMATION_OFFLINE_FBX_FBX_H_

#include "ozz/base/containers/string.h"
#include "ozz/base/containers/vector.h"

#include "ozz/animation/offline/raw_animation.h"

namespace ozz {
namespace animation {

//  Forward declares ozz runtime skeleton type.
class Skeleton;

namespace offline {

//  Forward declares ozz offline animation and skeleton types.
struct RawSkeleton;

namespace fbx {

// Imports an offline skeleton from _filename fbx document.
// _skeleton must point to a valid RawSkeleton instance, that will be cleared
// and filled with skeleton data extracted from the fbx document.
bool ImportFromFile(const char* _filename, RawSkeleton* _skeleton);

// Vector of imported animations.
typedef Vector<RawAnimation>::Std Animations;

// Imports an offline animation from _filename fbx document.
// _animation must point to a valid RawSkeleton instance, that will be cleared
// and filled with animation data extracted from the fbx document.
// _skeleton is a run-time Skeleton object used to select and sort animation
// tracks.
bool ImportFromFile(const char* _filename, const Skeleton& _skeleton,
                    float _sampling_rate, Animations* _animations);
}  // namespace fbx
}  // namespace offline
}  // namespace animation
}  // namespace ozz
#endif  // OZZ_OZZ_ANIMATION_OFFLINE_FBX_FBX_H_
