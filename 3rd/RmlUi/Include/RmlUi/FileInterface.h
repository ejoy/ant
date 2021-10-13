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

#ifndef RMLUI_CORE_FILEINTERFACE_H
#define RMLUI_CORE_FILEINTERFACE_H

#include "Platform.h"
#include "Types.h"
#include "Traits.h"

namespace Rml {

/**
	The abstract base class for application-specific file I/O.

	By default, RmlUi will use a file interface implementing the standard C file functions. If this is not sufficient,
	or your application wants more control over file I/O, this class should be derived, instanced, and installed
	through Rml::SetFileInterface() before you initialise RmlUi.

	@author Peter Curry
 */

class FileInterface : public NonCopyMoveable
{
public:
	virtual FileHandle Open(const std::string& path) = 0;
	virtual void Close(FileHandle file) = 0;
	virtual size_t Read(void* buffer, size_t size, FileHandle file) = 0;
	virtual size_t Length(FileHandle file) = 0;
	virtual std::string GetPath(const std::string& path) = 0;
};

} // namespace Rml
#endif
