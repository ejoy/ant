#include <lua.hpp>
#include <string>
#include <libimobiledevice/libimobiledevice.h>
#include "lockqueue.h"
#include "span.h"

namespace idevice {
    const char* errmsg(idevice_error_t err) {
        switch (err) {
        case IDEVICE_E_SUCCESS:
            return "success";
        case IDEVICE_E_INVALID_ARG:
            return "invalid arg";
        case IDEVICE_E_UNKNOWN_ERROR:
            return "unknown error";
        case IDEVICE_E_NO_DEVICE:
            return "no device";
        case IDEVICE_E_NOT_ENOUGH_DATA:
            return "not enough data";
        case IDEVICE_E_SSL_ERROR:
            return "ssl error";
        default:
            return "unexpected";
        }
    }

    struct list : public nonstd::span<char*> {
        list() : nonstd::span<char*>(0, 0) {
            int count = 0;
            err = idevice_get_device_list(&m_data, &count);
            m_size = count;
        }
        ~list()  {
            if (err != IDEVICE_E_SUCCESS) {
                return;
            }
            idevice_device_list_free(m_data);
        }
        idevice_error_t err;
    };

    struct device {
        device()
            : self_err(IDEVICE_E_NO_DEVICE)
            , conn_err(IDEVICE_E_NO_DEVICE)
        { }
        ~device()  {
            if (conn_err == IDEVICE_E_SUCCESS) {
                idevice_disconnect(conn);
            }
            if (self_err == IDEVICE_E_SUCCESS) {
                idevice_free(self);
            }
        }
        idevice_error_t connect(const char* udid, uint16_t port) {
            self_err = idevice_new(&self, udid);
            if (self_err != IDEVICE_E_SUCCESS) {
                return self_err;
            }
            conn_err = idevice_connect(self, port, &conn);
            return conn_err;
        }
        idevice_error_t recv(char *data, uint32_t len, uint32_t* recv_bytes) {
            return idevice_connection_receive_timeout(conn, data, len, recv_bytes, 1);
        }
        idevice_error_t send(const char *data, uint32_t len, uint32_t* sent_bytes) {
            return idevice_connection_send(conn, data, len, sent_bytes);
        }
        idevice_error_t close() {
            if (conn_err == IDEVICE_E_SUCCESS) {
                conn_err = IDEVICE_E_UNKNOWN_ERROR;
                return idevice_disconnect(conn);
            }
            return conn_err;
        }
        idevice_t            self;
        idevice_connection_t conn;
        idevice_error_t      self_err;
        idevice_error_t      conn_err;
    };

    struct event {
        idevice_event_type type;
        std::string        udid;
    };

    struct event_queue : private ant::lockqueue<event> {
        void event_cb(const idevice_event_t* e) {
            push({e->event, e->udid});
        }
        static void event_cb(const idevice_event_t* e, void* ud) {
            event_queue* self = (event_queue*)ud;
            self->event_cb(e);
        }
        static event_queue global;
        static void start() {
            idevice_event_subscribe(event_cb, &global);
        }
        static void stop() {
            idevice_event_unsubscribe();
        }
        static bool select(event& e) {
            return global.pop(e);
        }
    };

   event_queue event_queue::global;
}

static int ldestory(lua_State* L) {
    idevice::event_queue::stop();
    return 0;
}

static int llist(lua_State* L) {
    idevice::list l;
    if (l.err != IDEVICE_E_SUCCESS) {
        lua_pushnil(L);
        lua_pushstring(L, idevice::errmsg(l.err));
        return 2;
    }
    lua_newtable(L);
    lua_Integer n = 0;
    for (auto name : l) {
        lua_pushstring(L, name);
        lua_rawseti(L, -2, ++n);
    }
    return 1;
}

static int lselect(lua_State* L) {
    idevice::event e;
    if (!idevice::event_queue::select(e)) {
        return 0;
    }
    switch (e.type) {
    case IDEVICE_DEVICE_ADD:
        lua_pushstring(L, "add");
        break;
    case IDEVICE_DEVICE_REMOVE:
        lua_pushstring(L, "remove");
        break;
    case IDEVICE_DEVICE_PAIRED:
        lua_pushstring(L, "paired");
        break;
    default:
        return 0;
    }
    lua_pushlstring(L, e.udid.data(), e.udid.size());
    return 2;
}

static int lrecv(lua_State* L) {
    idevice::device* self = (idevice::device*)luaL_checkudata(L, 1, "idevice::device");
    lua_Integer len = luaL_optinteger(L, 2, LUAL_BUFFERSIZE);
    if (len > (std::numeric_limits<uint32_t>::max)()) {
    	return luaL_error(L, "bad argument #1 to 'recv' (invalid number)");
    }
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    char* buf = luaL_prepbuffsize(&b, (size_t)len);
    uint32_t rn = 0;
    if (auto err = self->recv(buf, len, &rn); err != IDEVICE_E_SUCCESS) {
        lua_pushnil(L);
        lua_pushstring(L, idevice::errmsg(err));
        return 2;
    }
    luaL_pushresultsize(&b, rn);
    return 1;
}

static int lsend(lua_State* L) {
    idevice::device* self = (idevice::device*)luaL_checkudata(L, 1, "idevice::device");
    size_t len;
    const char* buf = luaL_checklstring(L, 2, &len);
    uint32_t sn = 0;
    if (auto err = self->send(buf, len, &sn); err != IDEVICE_E_SUCCESS) {
        lua_pushnil(L);
        lua_pushstring(L, idevice::errmsg(err));
        return 2;
    }
    lua_pushinteger(L, sn);
    return 1;
}

static int lclose(lua_State* L) {
    idevice::device* self = (idevice::device*)luaL_checkudata(L, 1, "idevice::device");
    if (auto err = self->close(); err != IDEVICE_E_SUCCESS) {
        lua_pushnil(L);
        lua_pushstring(L, idevice::errmsg(err));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

static int lconnect_destory(lua_State* L) {
    idevice::device* self = (idevice::device*)luaL_checkudata(L, 1, "idevice::device");
    self->~device();
    return 0;
}

static int lconnect(lua_State* L) {
    const char* udid = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
	idevice::device* self = (idevice::device*)lua_newuserdata(L, sizeof(idevice::device));
	new (self) idevice::device;
    if (auto err = self->connect(udid, port); err != IDEVICE_E_SUCCESS) {
        lua_pushnil(L);
        lua_pushstring(L, idevice::errmsg(err));
        return 2;
    }
	if (luaL_newmetatable(L, "idevice::device")) {
		luaL_Reg l[] = {
			{ "recv", lrecv },
			{ "send", lsend },
			{ "close", lclose },
			{ "__gc", lconnect_destory },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_mobiledevice(lua_State* L) {
    luaL_Reg lib[] = {
        { "list", llist },
        { "select", lselect },
        { "connect", lconnect },
        { NULL, NULL},
    };
    luaL_newlib(L, lib);
    lua_newtable(L);
    lua_pushcfunction(L, ldestory);
    lua_setfield(L, -2, "__gc");
    lua_setmetatable(L, -2);
    idevice::event_queue::start();
    return 1;
}
