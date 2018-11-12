#pragma once

#include <Windows.h>

enum class ErrorHandle {
	Invalid = -1, // INVALID_HANDLE_VALUE
	Null = 0,     // NULL
};

template <ErrorHandle ErrorHandle>
class scoped_handle {
public:
	scoped_handle() : h(HANDLE(ErrorHandle)) { }
	scoped_handle(HANDLE h) : h(h) { }
	~scoped_handle() {
		if (HANDLE(ErrorHandle) != h) {
			::CloseHandle(h);
			h = HANDLE(ErrorHandle);
		}
	}
	operator HANDLE() const { return h; }
	operator bool()   const { return HANDLE(ErrorHandle) != h; }
	scoped_handle(scoped_handle const&) = delete;
	scoped_handle& operator=(scoped_handle const&) = delete;
protected:
	HANDLE h;
};
