#pragma once

#include <stddef.h>

class memory_file {
public:
	memory_file(const wchar_t* filename);
	~memory_file();
	const void* data() const;
	size_t      size() const;

private:
	void*  data_;
	size_t size_;
};
