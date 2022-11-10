#include "rdebug_eventfree.h"
#include "thunk/thunk.h"
#include <memory>

namespace remotedebug::eventfree {
    struct userdata {
        lua_Alloc l_allocf;
        void* l_ud;
        notify cb;
        void* ud;
#if !defined(RDEBUG_DISABLE_THUNK)
        std::unique_ptr<thunk> f;
#endif
    };
    static void* fake_allocf(void *ud, void *ptr, size_t osize, size_t nsize) {
        userdata* self = (userdata*)ud;
        if (ptr != NULL && nsize == 0 && self->cb) {
            self->cb(self->ud, ptr);
        }
        return self->l_allocf(self->l_ud, ptr, osize, nsize);
    }
    void* create(lua_State* L, notify cb, void* ud) {
        userdata* self = new userdata;
        self->cb = cb;
        self->ud = ud;
        self->l_allocf = lua_getallocf(L, &self->l_ud);
#if defined(RDEBUG_DISABLE_THUNK)
        lua_setallocf(L, fake_allocf, self);
#else
        self->f.reset(thunk_create_allocf((intptr_t)self, (intptr_t)fake_allocf));
        lua_setallocf(L, (lua_Alloc)self->f->data, self->l_ud);
#endif
        return self;
    }
    void destroy(lua_State* L, void* handle) {
        userdata* self = (userdata*)handle;
        lua_setallocf(L, self->l_allocf, self->l_ud);
        delete self;
    }
}
