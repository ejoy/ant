#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/FileInterface.h"
#include <stdio.h>
#include <string.h>

namespace Rml {

Stream::View::View()
: buf(nullptr)
, len(0)
, owner(false)
{ }

Stream::View::View(const uint8_t* buf, size_t len, bool owner)
: buf(buf)
, len(len)
, owner(owner)
{ }

Stream::View::View(Stream::View&& o)
: buf(o.buf)
, len(o.len)
, owner(o.owner)
{
	o.owner = false;
}

Stream::View::~View() {
	if (owner)
		free((void*)buf);
}

Stream::View::operator bool() const {
	return !!buf;
}

uint8_t Stream::View::operator[] (size_t i) const {
	return buf[i];
}

size_t Stream::View::size() const {
	return len;
}

static Stream::View ReadAll(const std::string& filename) {
	FileHandle handle = GetFileInterface()->Open(filename);
	if (!handle) {
		Log::Message(Log::Level::Warning, "Unable to open file %s.", filename.c_str());
		return {};
	}
	size_t len = GetFileInterface()->Length(handle);
	void* buf = malloc(len);
	len = GetFileInterface()->Read(buf, len, handle);
	GetFileInterface()->Close(handle);
	return {(const uint8_t*)buf, len, true};
}

Stream::Stream(const std::string& filename)
: url(filename)
, view(ReadAll(filename))
, pos(0)
{}

Stream::Stream(const std::string& name, const uint8_t* data, size_t sz)
: url(name)
, view {data, sz, false}
, pos(0)
{}

const std::string& Stream::GetSourceURL() const {
	return url;
}

uint8_t Stream::Peek() const {
	return view[pos];
}

bool Stream::End() const {
	return pos >= view.size();
}

void Stream::Next() {
	pos++;
}

void Stream::Undo() {
	pos--;
}

Stream::operator bool() const {
	return !!view;
}

}
