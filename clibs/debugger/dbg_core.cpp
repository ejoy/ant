#include <lua.hpp>
#include <algorithm>
#include <functional>
#include <map>
#include <mutex>
#include <thread>
#include <string.h>
#include "queue.h"

static int THREAD_CALLBACK = 0;
static int THREAD_TYPE = 0;

struct msg {
	msg(char* s, size_t l)
		: str(s)
		, len(l)
	{ }

	char*  str;
	size_t len;
};

struct msgqueue : public base::queue<msg, 16> {
    typedef base::queue<msg, 16> mybase;

    struct autodelete_msg : public msg {
        autodelete_msg(const msg& m)
            : msg(m.str, m.len)
        { }
        autodelete_msg(autodelete_msg&& o)
            : msg(o.str, o.len)
        {
            o.str = 0;
            o. len = 0;
        }
        ~autodelete_msg() {
            delete[] str;
        }
    };

    void push(const char* str, size_t len) {
        msg msg(new char[len], len);
        memcpy(msg.str, str, len);
        mybase::push(msg);
    }

    autodelete_msg pop() {
        auto res = autodelete_msg(mybase::front());
        mybase::pop();
        return std::move(res);
    }
};

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
};
masterThread* mThread = 0;

static int master_update(lua_State* L) {
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
    if (LUA_TFUNCTION != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_CALLBACK)) {
        return luaL_error(L, "Thread did not start.");
    }
    self.eachWorker([&](int handle, workerThread& worker){
        while (!worker.output.empty()) {
            auto msg = worker.output.pop();
            lua_pushvalue(L, -1);
            lua_pushinteger(L, handle);
            lua_pushlstring(L, msg.str, msg.len);
            lua_call(L, 2, 0);
        }
    });
    return 0;
}

static int master_send(lua_State* L) {
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
    self.getWorker((int)luaL_checkinteger(L, 2), [&](workerThread& worker){
        size_t len = 0;
        const char* str = luaL_checklstring(L, 3, &len);
        worker.input.push(str, len);
    });
    return 0;
}

static int master_broadcast(lua_State* L) {
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
    size_t len = 0;
    const char* str = luaL_checklstring(L, 2, &len);
    self.eachWorker([&](int handle, workerThread& worker){
        worker.input.push(str, len);
    });
    return 0;
}

static int master_exists(lua_State* L) {
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
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
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
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
    mThread = 0;
    masterThread& self = *(masterThread*)lua_touserdata(L, lua_upvalueindex(1));
    self.~masterThread();
    return 0;
}

static int master_start(lua_State* L){
    if (mThread) {
	    return luaL_error(L, "Master thread has started.");
    }
    if (LUA_TNIL != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_TYPE)) {
        return luaL_error(L, "Thread has started.");
    }
    lua_pushvalue(L, 1);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_TYPE);
    lua_pushvalue(L, 2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_CALLBACK);

    mThread = (masterThread*)lua_newuserdata(L, sizeof(masterThread));
    new (mThread) masterThread;
    
	static luaL_Reg lib[] = {
		{ "update", master_update },
		{ "send", master_send },
		{ "exists", master_exists },
		{ "foreach", master_foreach },
		{ "broadcast", master_broadcast },
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

static int worker_update(lua_State* L) {
    workerThread& self = *(workerThread*)lua_touserdata(L, lua_upvalueindex(1));
    if (self.input.empty()) {
        return 0;
    }
    if (LUA_TFUNCTION != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_CALLBACK)) {
        return luaL_error(L, "Thread did not start.");
    }
    while (!self.input.empty()) {
        auto msg = self.input.pop();
        lua_pushvalue(L, -1);
        lua_pushlstring(L, msg.str, msg.len);
        lua_call(L, 1, 0);
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
    if (mThread) mThread->delWorker(&self);
    self.~workerThread();
    return 0;
}

static int worker_start(lua_State* L) {
    if (!mThread) {
	    return luaL_error(L, "Must start master thread first.");
    }
    if (LUA_TNIL != lua_rawgetp(L, LUA_REGISTRYINDEX, &THREAD_TYPE)) {
        return luaL_error(L, "Thread has started.");
    }
    lua_pushvalue(L, 1);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_TYPE);
    lua_pushvalue(L, 2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &THREAD_CALLBACK);

    workerThread* thd = (workerThread*)lua_newuserdata(L, sizeof(workerThread));
    new (thd) workerThread;

	static luaL_Reg lib[] = {
		{ "update", worker_update },
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

    if (mThread) mThread->addWorker(thd);
    return 1;
}

static int start(lua_State* L) {
	const char* who = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
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

extern "C" __declspec(dllexport)
int luaopen_debugger_core(lua_State* L) {
	static luaL_Reg lib[] = {
		{ "start", start },
		{ "sleep", sleep },
	};	
	lua_newtable(L);
	luaL_setfuncs(L, lib, 0);
	return 1;
}
