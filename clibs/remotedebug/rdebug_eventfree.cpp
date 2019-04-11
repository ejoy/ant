#include "rdebug_eventfree.h"

namespace remotedebug::eventfree {
    struct userdata {
        lua_Alloc l_allocf;
        void* l_ud;
        notify notify;
        void* ud;
    };
    static void* fake_allocf(void *ud, void *ptr, size_t osize, size_t nsize) {
        userdata* self = (userdata*)ud;
        if (ptr != NULL && nsize == 0 && self->notify) {
            self->notify(self->ud, ptr);
        }
        return self->l_allocf(ud, ptr, osize, nsize);
    }
    void create(lua_State* L, notify notify, void* ud) {
        userdata* self = new userdata;
        self->notify = notify;
        self->ud = ud;
        self->l_allocf = lua_getallocf(L, &self->l_ud);
        lua_setallocf(L, fake_allocf, self);
    }
    void destroy(lua_State* L) {
        userdata* self;
        lua_getallocf(L, (void**)&self);
        lua_setallocf(L, self->l_allocf, self->l_ud);
        delete self;
    }
}
