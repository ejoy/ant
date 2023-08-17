#include <util/Stream.h>

namespace Rml {

Stream::Stream(std::string_view view)
: view(view)
, pos(0)
{}


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


}
