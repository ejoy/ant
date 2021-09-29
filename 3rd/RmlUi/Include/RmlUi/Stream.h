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

#ifndef RMLUI_CORE_STREAM_H
#define RMLUI_CORE_STREAM_H

#include "Platform.h"
#include "Traits.h"
#include "Types.h"

namespace Rml {

class StreamListener;

/**
	Abstract class for a media-independent byte stream.
	@author Lloyd Weehuizen
 */

class Stream : public NonCopyMoveable
{
public:
	Stream();
	virtual ~Stream();

	/// Closes the stream.
	virtual void Close();

	/// Obtain the source url of this stream (if available)
	const std::string& GetSourceURL() const;

	/// Are we at the end of the stream
	virtual bool IsEOS() const;

	/// Returns the size of this stream (in bytes).
	virtual size_t Length() const = 0;

	/// Returns the position of the stream pointer (in bytes).
	virtual size_t Tell() const = 0;

	/// Read from the stream.
	virtual size_t Read(void* buffer, size_t bytes) const = 0;
	/// Read from the stream and append to the string buffer
	virtual size_t Read(std::string& buffer, size_t bytes) const;


protected:
	/// Sets the mode on the stream; should be called by a stream when it is opened.
	void SetStreamDetails(const std::string& url);

private:
	std::string url;
};

} // namespace Rml
#endif
