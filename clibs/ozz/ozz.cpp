#include <lua.hpp>
#include <bx/allocator.h>
#include "fastio.h"

#include <functional>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/io/archive_traits.h>
#include <ozz/base/io/stream.h>

class HeapAllocator : public ozz::memory::Allocator {
public:
	size_t count = 0;

protected:
	struct Header {
		void* unaligned;
		size_t size;
	};
	void* Allocate(size_t _size, size_t _alignment) {
		const size_t to_allocate = _size + sizeof(Header) + _alignment - 1;
		char* unaligned = reinterpret_cast<char*>(malloc(to_allocate));
		if (!unaligned) {
			return nullptr;
		}
		char* aligned = ozz::Align(unaligned + sizeof(Header), _alignment);
		assert(aligned + _size <= unaligned + to_allocate);
		Header* header = reinterpret_cast<Header*>(aligned - sizeof(Header));
		assert(reinterpret_cast<char*>(header) >= unaligned);
		header->unaligned = unaligned;
		header->size = to_allocate;
		count += to_allocate;
		return aligned;
	}
	void Deallocate(void* _block) {
		if (_block) {
			Header* header = reinterpret_cast<Header*>(reinterpret_cast<char*>(_block) - sizeof(Header));
			count -= header->size;
			free(header->unaligned);
		}
	}
};

HeapAllocator g_heap_allocator;

static int
lmemory(lua_State* L) {
	lua_pushinteger(L, g_heap_allocator.count);
	return 1;
}

class MemoryPtrStream : public ozz::io::Stream {
public:
	MemoryPtrStream(const std::string_view &s) : ms(s){}
	bool opened() const override { return !ms.empty(); }
	size_t Read(void* _buffer, size_t _size) override{
		if (moffset + _size > ms.size()){
			return 0;
		}
		memcpy(_buffer, ms.data() + moffset, _size);
		moffset += (int)_size;
		return _size;
	}

	int Seek(int _offset, Origin _origin) override {
		int origin = 0;
		switch (_origin) {
			case kCurrent: 	origin = moffset; 		break;
			case kEnd: 		origin = (int)ms.size();break;
			case kSet:		origin = 0;				break;
			default:								return -1;
		}

		int r = (int)origin + _offset;
		if (r < 0 || r > ms.size()){
			return -1;
		}
		moffset = r;
		return 0;
	}

	int Tell() const override{ return moffset; }
	size_t Size() const override { return ms.size();}

public:
	size_t Write(const void* _buffer, size_t _size) override { assert(false && "Not support"); return 0; }
private:
	const std::string_view ms;
	int moffset = 0;
};

extern const char* check_read_animation(lua_State *L, ozz::io::IArchive &ia);
extern const char* check_read_skeleton(lua_State *L, ozz::io::IArchive &ia);
extern const char* check_read_raw_skeleton(lua_State *L, ozz::io::IArchive& ia);

static int
lload(lua_State *L){
	auto m = getmemory(L, 1);
	MemoryPtrStream ms(m);

	std::function<decltype(check_read_animation)> check_funcs[] = {
		check_read_animation, check_read_skeleton, check_read_raw_skeleton
	};
	
	const char* type = nullptr;
	for (auto f : check_funcs){
		ozz::io::IArchive ia(&ms);
		type = f(L, ia);
		if (type){
			break;
		}
		ms.Seek(0, ozz::io::Stream::kSet);
	}

	if (nullptr == type){
		return luaL_error(L, "Can not read ozz data");
	}
	lua_pushstring(L, type);
	return 2;
}

extern void init_animation(lua_State* L);
extern void init_skeleton(lua_State* L);
extern void init_skinning(lua_State* L);

extern "C" int
luaopen_ozz(lua_State *L) {
	luaL_checkversion(L);
	ozz::memory::SetDefaulAllocator(&g_heap_allocator);
	lua_newtable(L);
	init_animation(L);
	init_skeleton(L);
	init_skinning(L);
	lua_pushcfunction(L, lmemory);
	lua_setfield(L, -2, "memory");
	lua_pushcfunction(L, lload);
	lua_setfield(L, -2, "load");
	return 1;
}
