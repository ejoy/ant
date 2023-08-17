#pragma once

#include <string_view>

namespace Rml {

class Stream {
public:
	Stream(std::string_view view);
	uint8_t Peek() const;
	bool End() const;
	void Next();
	void Undo();
private:
	std::string_view view;
	size_t           pos;
};

}
