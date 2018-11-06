#include "memory_file.h"
#include "scoped_handle.h"
#include <stdint.h>

memory_file::memory_file(const wchar_t* filename)
	: data_(NULL)
	, size_(0)
{
	scoped_handle<ErrorHandle::Invalid> file(::CreateFileW(filename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, NULL));
	if (!file) {
		return;
	}
	LARGE_INTEGER file_size;
	if (!::GetFileSizeEx(file, &file_size)) {
		return;
	}
#if defined(_WIN64)
	size_t map_size = file_size.QuadPart;
#else
	if (file_size.HighPart > 0) {
		return;
	}
	size_t map_size = file_size.LowPart;
#endif
	if (0 == map_size) {
		return;
	}
	scoped_handle<ErrorHandle::Null> filemapping(::CreateFileMappingW(file, NULL, PAGE_READONLY, file_size.HighPart, file_size.LowPart, NULL));
	if (!filemapping) {
		return;
	}
	data_ = ::MapViewOfFile(filemapping, FILE_MAP_READ, 0, 0, map_size);
	if (!data_) {
		return;
	}
	size_ = map_size;
}

memory_file::~memory_file() {
	if (data_) {
		::UnmapViewOfFile(data_);
	}
}

void const* memory_file::data() const {
	return data_;
}

size_t memory_file::size() const {
	return size_;
}
