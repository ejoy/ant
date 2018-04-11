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

#include "ozz/animation/offline/tools/convert2skel.h"

#include <cstdlib>
#include <cstring>

#include "ozz/animation/offline/raw_skeleton.h"
#include "ozz/animation/offline/skeleton_builder.h"

#include "ozz/animation/runtime/skeleton.h"

#include "ozz/base/io/archive.h"
#include "ozz/base/io/stream.h"

#include "ozz/base/log.h"

#include "ozz/options/options.h"

// Declares command line options.
OZZ_OPTIONS_DECLARE_STRING(file, "Specifies input file", "", true)
OZZ_OPTIONS_DECLARE_STRING(skeleton, "Specifies ozz skeleton ouput file", "",
                           true)

static bool ValidateEndianness(const ozz::options::Option& _option,
                               int /*_argc*/) {
  const ozz::options::StringOption& option =
      static_cast<const ozz::options::StringOption&>(_option);
  bool valid = std::strcmp(option.value(), "native") == 0 ||
               std::strcmp(option.value(), "little") == 0 ||
               std::strcmp(option.value(), "big") == 0;
  if (!valid) {
    ozz::log::Err() << "Invalid endianess option." << std::endl;
  }
  return valid;
}

OZZ_OPTIONS_DECLARE_STRING_FN(
    endian,
    "Selects output endianness mode. Can be \"native\" (same as current "
    "platform), \"little\" or \"big\".",
    "native", false, &ValidateEndianness)

static bool ValidateLogLevel(const ozz::options::Option& _option,
                             int /*_argc*/) {
  const ozz::options::StringOption& option =
      static_cast<const ozz::options::StringOption&>(_option);
  bool valid = std::strcmp(option.value(), "verbose") == 0 ||
               std::strcmp(option.value(), "standard") == 0 ||
               std::strcmp(option.value(), "silent") == 0;
  if (!valid) {
    ozz::log::Err() << "Invalid log level option." << std::endl;
  }
  return valid;
}

OZZ_OPTIONS_DECLARE_STRING_FN(
    log_level,
    "Selects log level. Can be \"silent\", \"standard\" or \"verbose\".",
    "standard", false, &ValidateLogLevel)

OZZ_OPTIONS_DECLARE_BOOL(raw,
                         "Outputs raw skeleton, instead of runtime skeleton.",
                         false, false)

namespace ozz {
namespace animation {
namespace offline {

int SkeletonConverter::operator()(int _argc, const char** _argv) {
  // Parses arguments.
  ozz::options::ParseResult parse_result = ozz::options::ParseCommandLine(
      _argc, _argv, "1.1",
      "Imports a skeleton from a file and converts it to ozz binary raw or "
      "runtime skeleton format");
  if (parse_result != ozz::options::kSuccess) {
    return parse_result == ozz::options::kExitSuccess ? EXIT_SUCCESS
                                                      : EXIT_FAILURE;
  }

  // Initializes log level from options.
  ozz::log::Level log_level = ozz::log::GetLevel();
  if (std::strcmp(OPTIONS_log_level, "silent") == 0) {
    log_level = ozz::log::Silent;
  } else if (std::strcmp(OPTIONS_log_level, "standard") == 0) {
    log_level = ozz::log::Standard;
  } else if (std::strcmp(OPTIONS_log_level, "verbose") == 0) {
    log_level = ozz::log::Verbose;
  }
  ozz::log::SetLevel(log_level);

  // Imports skeleton from the file.
  ozz::log::Log() << "Importing file \"" << OPTIONS_file << "\"" << std::endl;

  if (!ozz::io::File::Exist(OPTIONS_file)) {
    ozz::log::Err() << "File \"" << OPTIONS_file << "\" doesn't exist."
                    << std::endl;
    return EXIT_FAILURE;
  }

  ozz::animation::offline::RawSkeleton raw_skeleton;
  if (!Import(OPTIONS_file, &raw_skeleton)) {
    ozz::log::Err() << "Failed to import file \"" << OPTIONS_file << "\""
                    << std::endl;
    return EXIT_FAILURE;
  }

  // Needs to be done before opening the output file, so that if it fails then
  // there's no invalid file outputted.
  ozz::animation::Skeleton* skeleton = NULL;
  if (!OPTIONS_raw) {
    // Builds runtime skeleton.
    ozz::log::Log() << "Builds runtime skeleton." << std::endl;
    ozz::animation::offline::SkeletonBuilder builder;
    skeleton = builder(raw_skeleton);
    if (!skeleton) {
      ozz::log::Err() << "Failed to build runtime skeleton." << std::endl;
      return EXIT_FAILURE;
    }
  }

  // Prepares output stream. File is a RAII so it will close automatically at
  // the end of this scope.
  // Once the file is opened, nothing should fail as it would leave an invalid
  // file on the disk.
  {
    ozz::log::Log() << "Opens output file: " << OPTIONS_skeleton << std::endl;
    ozz::io::File file(OPTIONS_skeleton, "wb");
    if (!file.opened()) {
      ozz::log::Err() << "Failed to open output file: " << OPTIONS_skeleton
                      << std::endl;
      ozz::memory::default_allocator()->Delete(skeleton);
      return EXIT_FAILURE;
    }

    // Initializes output endianness from options.
    ozz::Endianness endianness = ozz::GetNativeEndianness();
    if (std::strcmp(OPTIONS_endian, "little")) {
      endianness = ozz::kLittleEndian;
    } else if (std::strcmp(OPTIONS_endian, "big")) {
      endianness = ozz::kBigEndian;
    }
    ozz::log::Log() << (endianness == ozz::kLittleEndian ? "Little" : "Big")
                    << " Endian output binary format selected." << std::endl;

    // Initializes output archive.
    ozz::io::OArchive archive(&file, endianness);

    // Fills output archive with the skeleton.
    if (OPTIONS_raw) {
      ozz::log::Log() << "Outputs RawSkeleton to binary archive." << std::endl;
      archive << raw_skeleton;
    } else {
      ozz::log::Log() << "Outputs Skeleton to binary archive." << std::endl;
      archive << *skeleton;
    }
    ozz::log::Log() << "Skeleton binary archive successfully outputed."
                    << std::endl;
  }

  // Delete local objects.
  ozz::memory::default_allocator()->Delete(skeleton);

  return EXIT_SUCCESS;
}
}  // namespace offline
}  // namespace animation
}  // namespace ozz
