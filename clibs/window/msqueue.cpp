#include <queue>
#include <mutex>

extern "C" {
#include "msqueue.h"
#include <lua-seri.h>
}

static std::queue<void*> g_queue;
static std::mutex        g_mutex;

static void queue_push(void* data) {
    std::unique_lock<std::mutex> _(g_mutex);
    g_queue.push(data);
}

static void* queue_pop() {
    std::unique_lock<std::mutex> _(g_mutex);
    if (g_queue.empty()) {
        return NULL;
    }
    void* data = g_queue.front();
    g_queue.pop();
    return data;
}

void msqueue_push(lua_State* L, int idx) {
    void* data = seri_pack(L, idx, NULL);
    queue_push(data);
}

int msqueue_pop(lua_State* L) {
    void* data = queue_pop();
    if (!data) {
        return 0;
    }
    return seri_unpackptr(L, data);
}
