#include "lua.hpp"

#include <cstdint>
#include <vector>
#include <forward_list>

#include <cassert>

#include "ecs/world.h"

struct queue_node {
	static constexpr uint8_t NUM_MASK = 1;
	static constexpr uint16_t QUEUE_NUM = NUM_MASK * 64;
	uint64_t masks[NUM_MASK] = {0};

    constexpr void clear() {
        for (uint32_t ii=0; ii<NUM_MASK; ++ii){
            masks[ii] = 0;
        }
    }

    bool check(uint8_t queue) const {
        const uint8_t eidx = queue / 64;
        const uint8_t sidx = queue % 64;
        assert(eidx < NUM_MASK && "Max queue is 64");

        return 0 != (masks[eidx] & (1ull << sidx));
    }

    void set(uint8_t queue, bool value){
        const uint8_t eidx = queue / 64;
        assert(eidx < NUM_MASK && "Max queue is 64");
        const uint8_t sidx = queue % 64;

        if (value){
            masks[eidx] |= (1ull << sidx);
        } else {
            masks[eidx] &= ~(1ull << sidx);
        }
    }
};

struct queue_container {
    queue_container(int c): nodes(c){}
    int alloc(){
        if (!freelist.empty()){
            const int Qidx = freelist.front();
            freelist.pop_front();
            nodes[Qidx].clear();
            return Qidx;
        }

        const int Qidx = n++;
        if (n == nodes.size()){
            nodes.resize(n*2);
        }
        return Qidx;
    }

    void dealloc(int Qidx){
        freelist.push_front(Qidx);
    }

    inline bool isvalid(int Qidx) const {
        return 0 <= Qidx && Qidx < n;
    }

    inline bool check(int Qidx, uint8_t queue) const {
        return nodes[Qidx].check(queue);
    }

    inline void set(int Qidx, uint8_t queue, bool value) {
        nodes[Qidx].set(queue, value);
    }

    std::vector<queue_node> nodes;
    std::forward_list<int>   freelist;
    int n = 0;
};

struct queue_container* queue_create(){
    return new struct queue_container(256);
}

void queue_destroy(struct queue_container* Q){
    delete Q;
}

bool queue_check(struct queue_container* Q, int Qidx, uint8_t queue){
    return Q->check(Qidx, queue);
}

void queue_set(struct queue_container* Q, int Qidx, uint8_t queue, bool value){
    return Q->set(Qidx, queue, value);
}

static int
lqueue_dealloc(lua_State *L){
    auto w = getworld(L);
    const int Qidx = (int)luaL_checkinteger(L, 1);
    if (!w->Q->isvalid(Qidx)){
        return luaL_error(L, "Invalid Qidx");
    }

    w->Q->dealloc(Qidx);
	return 0;
}

static int
lqueue_alloc(lua_State *L){
    auto w = getworld(L);
    lua_pushinteger(L, w->Q->alloc());
    return 1;
}

static int
lqueue_set(lua_State *L){
    auto w = getworld(L);
    const int Qidx = (int)luaL_checkinteger(L, 1);
    if (!w->Q->isvalid(Qidx)){
        luaL_error(L, "Invalid Qidx");
    }

    const uint8_t queue = (uint8_t)luaL_checkinteger(L, 2);
    const int value = lua_toboolean(L, 3);
    queue_set(w->Q, Qidx, queue, value != 0);
    return 0;
}

static int
lqueue_check(lua_State *L){
    auto w = getworld(L);
    const int Qidx = (int)luaL_checkinteger(L, 1);
    if (!w->Q->isvalid(Qidx)){
        luaL_error(L, "Invalid Qidx");
    }

    const uint8_t queue = (uint8_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, queue_check(w->Q, Qidx, queue));
    return 1;
}

extern "C" int
luaopen_render_queue(lua_State *L){
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "dealloc",lqueue_dealloc},
		{ "alloc",	lqueue_alloc},
		{ "set",	lqueue_set},
        { "check",  lqueue_check},
		{ nullptr, 	nullptr },
	};
	luaL_newlibtable(L,l);
    lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}