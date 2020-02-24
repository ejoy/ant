#pragma once

#if !defined(NDEBUG)

void IM_THROW(const char* err);

#define IM_ASSERT(_EXPR) do { if (!(_EXPR)) IM_THROW(#_EXPR); } while(0)

#endif
