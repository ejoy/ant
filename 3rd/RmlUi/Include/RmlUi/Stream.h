#pragma once

#include "Types.h"

namespace Rml {

class Stream {
public:
	struct View {
		const uint8_t* buf;
		size_t         len;
		bool           owner;
		View();
		View(const uint8_t* buf, size_t len, bool owner);
		View(View&& o);
		~View();
		View(const View&) = delete;
		View& operator=(const View&) = delete;
		View& operator=(View&&) = delete;

		operator bool() const;
		uint8_t operator[] (size_t i) const;
		size_t size() const;
	};
	Stream(const std::string& filename);
	Stream(const std::string& name, const uint8_t* data, size_t sz);

	const std::string& GetSourceURL() const;
	uint8_t Peek() const;
	bool End() const;
	void Next();
	void Undo();
	operator bool() const;

private:
	std::string    url;
	View           view;
	size_t         pos;
};

}
