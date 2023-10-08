#include <lj_frame.h>

#include "compat/internal.h"

int lua_stacklevel(lua_State* L) {
    int level = 0;
    cTValue *frame, *nextframe, *bot = tvref(L->stack) + LJ_FR2;
    /* Traverse frames backwards. */
    for (nextframe = frame = L->base - 1; frame > bot;) {
        if (frame_gc(frame) == obj2gco(L)) {
            level--;
        }
        level++;
        nextframe = frame;
        if (frame_islua(frame)) {
            frame = frame_prevl(frame);
        }
        else {
            if (frame_isvarg(frame))
                level--; /* Skip vararg pseudo-frame. */
            frame = frame_prevd(frame);
        }
    }
    return level;
}
