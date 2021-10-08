#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Debug.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/FileInterface.h"
#include <stdio.h>
#include <string.h>

namespace Rml {

Stream::Stream(const std::string& filename)
: url(filename)
, owner(false)
, buf(nullptr)
, len(0)
, pos(0)
{
	FileHandle handle = GetFileInterface()->Open(filename);
	if (!handle) {
		Log::Message(Log::Level::Warning, "Unable to open file %s.", filename.c_str());
		return;
	}

	size_t len = GetFileInterface()->Length(handle);
	buf = (const uint8_t*)malloc(len);
	len = GetFileInterface()->Read((void*)buf, len, handle);
	GetFileInterface()->Close(handle);
	owner = true;
}

Stream::Stream(const std::string& name, const uint8_t* data, size_t sz)
: url(name)
, owner(false)
, buf(data)
, len(sz)
, pos(0)
{}

Stream::~Stream()
{
	if (owner)
		free((void*)buf);
}

const std::string& Stream::GetSourceURL() const {
	return url;
}

uint8_t Stream::Peek() const {
	return buf[pos];
}

bool Stream::End() const {
	return pos >= len;
}

void Stream::Next() {
	pos++;
}

void Stream::Undo() {
	pos--;
}

Stream::operator bool() const {
	return !!buf;
}

}
