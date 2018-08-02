#include <lua.hpp>
#include <algorithm>
#include <functional>
#include <map>
#include <mutex>
#include <thread>
#include <string.h>
#include "msgqueue.h"

static int THREAD_MASTER = 0;
static int THREAD_WORKER = 0;

struct workerThread {
    msgqueue input;
    msgqueue output;
};

struct masterThread {
    void addWorker(workerThread* worker) {
        std::unique_lock<std::mutex> lock(mutex);
        handleSeed++;
        workers.insert(std::make_pair(handleSeed, worker));
    }
    void delWorker(workerThread* worker) {
        std::unique_lock<std::mutex> lock(mutex);
        for (auto it = workers.begin(); it != workers.end();) {
            if (it->second == worker) {
                workers.erase(it);
                return;
            }
        }
    }
    void getWorker(int handle, std::function<void(workerThread&)> f) {
        std::unique_lock<std::mutex> lock(mutex);
        auto it = workers.find(handle);
        if (it == workers.end()) {
            return;
        }
        f(*(it->second));
    }
    void eachWorker(std::function<void(int, workerThread&)> f) {
        std::unique_lock<std::mutex> lock(mutex);
        for (auto p : workers) {
            f(p.first, *(p.second));
        }
    }

    std::map<int, workerThread*> workers;
    int handleSeed = 0;
    std::mutex mutex;
    bool start = false;
};
masterThread mThread;

static int master_recv(lua_State* L) {
    masterThread& self = mThread;
    int r = 0;
    self.getWorker((int)luaL_checkinteger(L, 2), [&](workerThread& worker){
        msgqueue::autodelete_msg msg;
        if (worker.output.try_pop(msg)) {
            lua_pushlstring(L, msg.str, msg.len);
            r = 1;
        }
    });
    return r;
}

static int master_send(lua_State* L) {
    masterThread& self = mThread;
    self.getWorker((int)luaL_checkinteger(L, 2), [&](workerThread& worker){
        size_t len = 0;
        const char* str = luaL_checklstring(L, 3, &len);
        worker.input.push(str, len);
    });
    return 0;
}

static int master_exists(lua_State* L) {
    masterThread& self = mThread;
    bool res = false;
    self.getWorker((int)luaL_checkinteger(L, 2), [&](workerThread& worker){
        res = true;
    });
    lua_pushboolean(L, res);
    return 1;
}

static int ipairs(lua_State* L) {
    lua_Integer n = lua_tointeger(L, lua_upvalueindex(2));
    lua_pushinteger(L, n + 1);
    lua_replace(L, lua_upvalueindex(2));
    lua_geti(L, lua_upvalueindex(1), n);
    return 1;
}

static int master_foreach(lua_State* L) {
    masterThread& self = mThread;
    lua_newtable(L);
    int n = 0;
    self.eachWorker([&](int handle, workerThread& worker){
        lua_pushinteger(L, handle);
        lua_seti(L, -2, ++n);
    });
    lua_pushinteger(L, 1);
    lua_pushcclosure(L, ipairs, 2);
    return 1;
}

static int master_gc(lua_State* L) {
    mThread.start = false;
    return 0;
}

static int master_start(lua_State* L){
    if (mThread.start) {
        return 0;
    }
    if (LUA_TNIL != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_MASTER)) {
        return luaL_error(L, "Thread has started.");
    }
    lua_pushvalue(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_MASTER);

    lua_newuserdata(L, 1);
    
    static luaL_Reg lib[] = {
        { "recv", master_recv },
        { "send", master_send },
        { "exists", master_exists },
        { "foreach", master_foreach },
        { "__gc", master_gc },
        { NULL, NULL }
    };    
    lua_newtable(L);
    lua_pushvalue(L, -2);
    luaL_setfuncs(L, lib, 1);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    return 1;
}

static int worker_recv(lua_State* L) {
    workerThread& self = *(workerThread*)lua_touserdata(L, lua_upvalueindex(1));
    msgqueue::autodelete_msg msg;
    if (self.input.try_pop(msg)) {
        lua_pushlstring(L, msg.str, msg.len);
        return 1;
    }
    return 0;
}

static int worker_send(lua_State* L) {
    workerThread& self = *(workerThread*)lua_touserdata(L, lua_upvalueindex(1));
    size_t len = 0;
    const char* str = luaL_checklstring(L, 2, &len);
    self.output.push(str, len);
    return 0;
}

static int worker_gc(lua_State* L) {
    workerThread& self = *(workerThread*)lua_touserdata(L, lua_upvalueindex(1));
    mThread.delWorker(&self);
    self.~workerThread();
    return 0;
}

static int worker_start(lua_State* L) {
    if (LUA_TNIL != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_WORKER)) {
        return luaL_error(L, "Thread has started.");
    }
    lua_pushvalue(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_WORKER);

    workerThread* thd = (workerThread*)lua_newuserdata(L, sizeof(workerThread));
    new (thd) workerThread;

    static luaL_Reg lib[] = {
        { "recv", worker_recv },
        { "send", worker_send },
        { "__gc", worker_gc },
        { NULL, NULL }
    };    
    lua_newtable(L);
    lua_pushvalue(L, -2);
    luaL_setfuncs(L, lib, 1);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);

    mThread.addWorker(thd);
    return 1;
}

static int start(lua_State* L) {
    const char* who = luaL_checkstring(L, 1);
    if (strcmp(who, "master") == 0) {
        return master_start(L);
    }
    else if (strcmp(who, "worker") == 0) {
        return worker_start(L);
    }
    return luaL_error(L, "Thread type `%s` error.", who);
}

static int sleep(lua_State* L) {
    std::this_thread::sleep_for(std::chrono::milliseconds((int)luaL_checkinteger(L, 1)));
    return 0;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_debugger_backend(lua_State* L) {
    static luaL_Reg lib[] = {
        { "start", start },
        { "sleep", sleep },
        { NULL, NULL },
    };    
    lua_newtable(L);
    luaL_setfuncs(L, lib, 0);
    return 1;
}
