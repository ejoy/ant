#include "lua.hpp"
#include "queue.h"
#include "node_container.h"

#include "ecs/world.h"
#include <cstdint>
#include <cassert>

struct queue_node {
	static constexpr uint8_t NUM_MASK = MAX_VISIBLE_QUEUE / 64;
	uint64_t masks[NUM_MASK] = {0};

    constexpr void clear() {
        for (uint32_t ii=0; ii<NUM_MASK; ++ii){
            masks[ii] = 0;
        }
    }

    constexpr void fetch(uint64_t *outmasks) const {
        for (int ii=0; ii<NUM_MASK; ++ii){
            outmasks[ii] = masks[ii];
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

    void set(queue_node &n, bool value) {
        if (value){
            for(uint8_t ii=0; ii<NUM_MASK; ++ii){
                masks[ii] |= n.masks[ii];
            }
        } else {
            for(uint8_t ii=0; ii<NUM_MASK; ++ii){
                masks[ii] &= ~(n.masks[ii]);
            }
        }
    }
};

struct queue_container : public node_container<queue_node>{
    queue_container(int c)
        : node_container<queue_node>(c)
        {}
    inline void fetch(int Qidx, uint64_t *outmask) const {
        return nodes[Qidx].fetch(outmask);
    }

    inline bool check(int Qidx, uint8_t queue) const {
        return nodes[Qidx].check(queue);
    }

    inline void set(int Qidx, uint8_t queue, bool value) {
        nodes[Qidx].set(queue, value);
    }

    inline void set(int Qidx, int nextQidx, bool value) {
        nodes[Qidx].set(nodes[nextQidx], value);
    }
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

void queue_set_by_index(struct queue_container *Q, int Qidx, int nextQidx, bool value){
    return Q->set(Qidx, nextQidx, value);
}

void queue_fetch(struct queue_container* Q, int Qidx, uint64_t *outmasks){
    return Q->fetch(Qidx, outmasks);
}

int
queue_dealloc(struct queue_container* Q, int Qidx){
    if (Q->isvalid(Qidx)){
        Q->dealloc(Qidx);
        return 1;
    }
    return 0;
}

static int
lqueue_dealloc(lua_State *L){
    auto w = getworld(L);
    const int Qidx = (int)luaL_checkinteger(L, 1);
    if (!queue_dealloc(w->Q, Qidx)){
        return luaL_error(L, "Invalid Qidx");
    }
	return 0;
}

int
queue_alloc(struct queue_container* Q){
    return Q->alloc();
}

static int
lqueue_alloc(lua_State *L){
    auto w = getworld(L);
    lua_pushinteger(L, queue_alloc(w->Q));
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
lqueue_fetch(lua_State *L){
    auto w = getworld(L);
    const int Qidx = (int)luaL_checkinteger(L, 1);
    if (!w->Q->isvalid(Qidx)){
        luaL_error(L, "Invalid Qidx");
    }

    uint64_t masks[queue_node::NUM_MASK];
    queue_fetch(w->Q, Qidx, masks);

    for (uint8_t ii=0; ii<queue_node::NUM_MASK; ++ii){
        lua_pushinteger(L, masks[ii]);
    }
    return queue_node::NUM_MASK;
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
        { "fetch",  lqueue_fetch},
        { "check",  lqueue_check},
		{ nullptr, 	nullptr },
	};
	luaL_newlibtable(L,l);
    lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}