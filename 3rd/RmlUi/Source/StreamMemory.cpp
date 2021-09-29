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

#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Debug.h"
#include <string.h>
#include <stdio.h>

namespace Rml {

const int DEFAULT_BUFFER_SIZE = 256;
const int BUFFER_INCREMENTS = 256;

StreamMemory::StreamMemory() 
{
	buffer = nullptr;
	buffer_ptr = nullptr;
	buffer_size = 0;
	buffer_used = 0;
	owns_buffer = true;
	Reallocate(DEFAULT_BUFFER_SIZE);
}

StreamMemory::StreamMemory(size_t initial_size)
{
	buffer = nullptr;
	buffer_ptr = nullptr;
	buffer_size = 0;
	buffer_used = 0;
	owns_buffer = true;
	Reallocate(initial_size);
}

StreamMemory::StreamMemory(const uint8_t* _buffer, size_t _buffer_size)
{
	buffer = (uint8_t*)_buffer;
	buffer_size = _buffer_size;
	buffer_used = _buffer_size;
	owns_buffer = false;
	buffer_ptr = buffer;	
}

StreamMemory::~StreamMemory() 
{
	if ( owns_buffer )
		free( buffer );
}

void StreamMemory::Close() 
{
	Stream::Close();
}

bool StreamMemory::IsEOS() const 
{
	return buffer_ptr >= buffer + buffer_used;
}

// Get current offset
size_t StreamMemory::Tell() const 
{
	return buffer_ptr - buffer;
}

size_t StreamMemory::Length() const 
{
	return buffer_used;
}

// Read bytes from the buffer, advancing the internal pointer
size_t StreamMemory::Read(void *_buffer, size_t bytes) const
{
	bytes = Math::ClampUpper(bytes, (size_t) (buffer + buffer_used - buffer_ptr));

	memcpy(_buffer, buffer_ptr, bytes);

	buffer_ptr += bytes;

	return bytes;
}


void StreamMemory::Erase( size_t offset, size_t bytes )
{
	bytes = Math::ClampUpper(bytes, buffer_used - offset);
	memmove(&buffer[offset], &buffer[offset + bytes], buffer_used - offset - bytes);
	buffer_used -= bytes;	
}

void StreamMemory::SetSourceURL(const std::string& url)
{
	SetStreamDetails(url);
}

// Resize the buffer
bool StreamMemory::Reallocate( size_t size ) 
{	
	RMLUI_ASSERT( owns_buffer );
	if ( !owns_buffer )
		return false;
	
	uint8_t *new_buffer = (uint8_t*)realloc( buffer, buffer_size + size );
	if ( new_buffer == nullptr )
		return false;

	buffer_ptr = new_buffer + ( buffer_ptr - buffer );

	buffer = new_buffer;
	buffer_size += size;
  
	return true;
}

} // namespace Rml
