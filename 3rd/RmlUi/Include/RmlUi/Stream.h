#pragma once

#include "Platform.h"
#include "Traits.h"
#include "Types.h"

namespace Rml {

class Stream : public NonCopyMoveable {
public:
	Stream(const std::string& filename);
	Stream(const std::string& name, const uint8_t* data, size_t sz);
	~Stream();

	const std::string& GetSourceURL() const;
	uint8_t Peek() const;
	bool End() const;
	void Next();
	void Undo();
	operator bool() const;

private:
	std::string    url;
	const uint8_t* buf;
	size_t         len;
	size_t         pos;
	bool           owner;
};

}
