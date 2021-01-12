/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CONFIG_CONFIG_H
#define RMLUI_CONFIG_CONFIG_H

/*
 * This file provides the means to configure various types used across RmlUi. It is possible to override container
 * types with your own, provided they are compatible with STL, or customize STL containers, for example by setting
 * custom allocators. This file may be edited directly, or can be copied to an alternate location, modified, and
 * included by setting the CMake option CUSTOM_CONFIGURATION_FILE (RMLUI_CUSTOM_CONFIGURATION_FILE preprocessor 
 * define) to the path of that file.
 */

#ifdef RMLUI_CUSTOM_CONFIGURATION_FILE
#include RMLUI_CUSTOM_CONFIGURATION_FILE
#else
#include <utility>
#include <vector>
#include <string>
#include <stack>
#include <list>
#include <functional>
#include <queue>
#include <array>
#include <unordered_map>
#include <memory>

#ifdef RMLUI_NO_THIRDPARTY_CONTAINERS
#include <set>
#include <unordered_set>
#else
#include "Containers/chobo/flat_map.hpp"
#include "Containers/chobo/flat_set.hpp"
#include "Containers/robin_hood.h"
#endif	// RMLUI_NO_THIRDPARTY_CONTAINERS

namespace Rml {

// Default matrix type to be used. This alias may be set to ColumnMajorMatrix4f or RowMajorMatrix4f. This alias can not
// be set here because matrix types are defined after this include in Core/Types.h.
#ifdef RMLUI_MATRIX_ROW_MAJOR
#define RMLUI_MATRIX4_TYPE RowMajorMatrix4f
#else
#define RMLUI_MATRIX4_TYPE ColumnMajorMatrix4f
#endif

// A way to disable 'final' specified for Rml::Releaser class. It breaks EASTL.
#define RMLUI_RELEASER_FINAL final

// Containers types.
template<typename T>
using Vector = std::vector<T>;
template<typename T, size_t N = 1>
using Array = std::array<T, N>;
template<typename T>
using Stack = std::stack<T>;
template<typename T>
using List = std::list<T>;
template<typename T>
using Queue = std::queue<T>;
template<typename T1, typename T2>
using Pair = std::pair<T1, T2>;
template <typename Key, typename Value>
using UnorderedMultimap = std::unordered_multimap< Key, Value >;
#ifdef RMLUI_NO_THIRDPARTY_CONTAINERS
template <typename Key, typename Value>
using UnorderedMap = std::unordered_map< Key, Value >;
template <typename Key, typename Value>
using SmallUnorderedMap = UnorderedMap< Key, Value >;
template <typename T>
using UnorderedSet = std::unordered_set< T >;
template <typename T>
using SmallUnorderedSet = std::unordered_set< T >;
template <typename T>
using SmallOrderedSet = std::set< T >;
#else
template < typename Key, typename Value>
using UnorderedMap = robin_hood::unordered_flat_map< Key, Value >;
template <typename Key, typename Value>
using SmallUnorderedMap = chobo::flat_map< Key, Value >;
template <typename T>
using UnorderedSet = robin_hood::unordered_flat_set< T >;
template <typename T>
using SmallUnorderedSet = chobo::flat_set< T >;
template <typename T>
using SmallOrderedSet = chobo::flat_set< T >;
#endif	// RMLUI_NO_THIRDPARTY_CONTAINERS
template<typename Iterator>
inline std::move_iterator<Iterator> MakeMoveIterator(Iterator it) { return std::make_move_iterator(it); }

// Utilities.
template <typename T>
using Hash = std::hash<T>;
template<typename T>
using Function = std::function<T>;

// Strings.
using String = std::string;
using StringList = Vector< String >;
using U16String = std::u16string;

// Smart pointer types.
template<typename T>
using UniquePtr = std::unique_ptr<T>;
template<typename T>
class Releaser;
template<typename T>
using UniqueReleaserPtr = std::unique_ptr<T, Releaser<T>>;
template<typename T>
using SharedPtr = std::shared_ptr<T>;
template<typename T>
using WeakPtr = std::weak_ptr<T>;
template<typename T, typename... Args>
inline SharedPtr<T> MakeShared(Args&&... args) { return std::make_shared<T, Args...>(std::forward<Args>(args)...); }
template<typename T, typename... Args>
inline UniquePtr<T> MakeUnique(Args&&... args) { return std::make_unique<T, Args...>(std::forward<Args>(args)...); }

}

#endif	// RMLUI_USER_CONFIG_FILE

#endif  // RMLUI_CONFIG_CONFIG_H
