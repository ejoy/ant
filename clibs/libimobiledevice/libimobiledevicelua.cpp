//
//  libimobiledevicelua.cpp
//  imobiledevicelua
//
//  Created by ejoy on 2018/4/25.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#include <stdio.h>
extern "C"
{
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <libimobiledevice/libimobiledevice.h>
#include <map>
#include <string>

struct ConnectID{
    std::string device_id;
    uint16_t port;

    ConnectID(const std::string& d_id, uint16_t p) {
        device_id = d_id;
        port = p;
    }

    bool operator == (const ConnectID& rhs) const {
        return (device_id == rhs.device_id && port == rhs.port);
    }

    bool operator < (const ConnectID& rhs) const {
        return (device_id < rhs.device_id || port < rhs.port);
    }
};

extern "C" int luaopen_libimobiledevicelua(lua_State* L);

std::map<std::string, idevice_t> g_device_map;
std::map<ConnectID, idevice_connection_t> g_connect_id_map;

void TypeError(int var_idx, const char* func_name, const char* correct_type, lua_State *L) {
    printf("ERROR: %d variable in function: %s should be %s\n", var_idx, func_name, correct_type);
}

bool is_init = false;

bool DisconnectDevice(const char* udid, uint16_t port) {
    auto iter = g_connect_id_map.find(ConnectID(udid, port));
    if(iter == g_connect_id_map.end()) {
        return true;
    }

    idevice_error_t err = idevice_disconnect(iter->second);
    if(err == IDEVICE_E_SUCCESS) {
        g_connect_id_map.erase(iter);
        return true;
    }

    return false;
}


void EventCallback(const idevice_event_t* event, void* user_data) {
    const char* event_device_id = event->udid;
    if(event_device_id) {
        enum idevice_event_type event_type = event->event;
        switch (event_type) {
            case IDEVICE_DEVICE_ADD: {
                auto iter = g_device_map.find(event_device_id);
                if(iter == g_device_map.end()) {
                    printf("%s connected\n", event_device_id);
                    //add device
                    idevice_t new_device;
                    idevice_error_t err = idevice_new(&new_device, event_device_id);
                    if(err == IDEVICE_E_SUCCESS) {
                        g_device_map.emplace(event_device_id, new_device);
                    } else {
                        printf("failed to create %s device, error code %d \n", event_device_id, err);
                    }
                }
                
                //need to call the lua function
            }
                break;
            case IDEVICE_DEVICE_REMOVE: {
                //todo
                //DisconnectDevice(event_device_id);
                g_device_map.erase(event_device_id);
                
                printf("%s disconnected\n", event_device_id);
            }
                break;
            case IDEVICE_DEVICE_PAIRED: {
                //nothing to do for now
            }
                break;
            default:
                break;
        }
    }
}

idevice_event_cb_t event_cb;
//init the state and update the device map;
void Init() {
    char **device_names = nullptr;
    int device_count = 0;
    
    idevice_error_t err = idevice_get_device_list(&device_names, &device_count);
    
    if(err == IDEVICE_E_SUCCESS) {
        for(int i = 0; i < device_count; ++i) {
            idevice_t new_device;
            err = idevice_new(&new_device, device_names[i]);
            if(err != IDEVICE_E_SUCCESS) {
                printf("fail to create new device with udid %s\n", device_names[i]);
                continue;
            } else {
                printf("device name %s\n", device_names[i]);
            }
            
 //           printf("create new device NO.%d, udid: %s\n", i, device_names[i]);
            g_device_map.emplace(std::string(device_names[i]), new_device);
        }
    }    
    
    event_cb = EventCallback;
    idevice_event_subscribe(event_cb, NULL);
    is_init = true;
}

static int GetDevices(lua_State* L) {
    if(!is_init)
        Init();
    
    lua_newtable(L);
    
    auto iter = g_device_map.begin();

    int count = 1;
    for(; iter != g_device_map.end(); ++iter) {
        lua_pushstring(L, iter->first.data());
        lua_rawseti(L, -2, count);
        
        ++count;
    }
    
    return 1;
}

//input is the udid string, and port
static int Connect(lua_State* L) {
    std::string udid;
    int port;
    if(lua_isnumber(L, -1)) {
        port = lua_tonumber(L, -1);
        lua_pop(L, 1);
    } else {
        TypeError(2, "Connect", "Number", L);
        return 0;
    }

    if(lua_isstring(L, -1)) {
        //get the udid string
        udid = lua_tostring(L, -1);
        lua_pop(L, 1);
 //       printf("udid %s\n", udid.data());
    } else {
        TypeError(1, "Connect", "String", L);
        return 0;
    }   
    
    auto iter = g_device_map.find(udid);
    if(iter == g_device_map.end()) {
        printf("device with udid: %s not found\n", udid.data());
        return 0;
    }

    ConnectID cnt_id(udid, port);

    auto c_iter = g_connect_id_map.find(cnt_id);
    if(c_iter != g_connect_id_map.end()) {
        printf("udid: %s and port: %d was already connected\n", udid.data(), port);
        return 0;
    }

    idevice_connection_t new_connection;
    idevice_error_t err = idevice_connect(iter->second, port, &new_connection);
    if(err == IDEVICE_E_SUCCESS) {
        g_connect_id_map.emplace(cnt_id, new_connection);
        printf("new connection created with udid: %s and port: %d\n", udid.data(), port);
    } else {
        printf("fail to create connection, udid: %s, port: %d\n", udid.data(), port);
        return 0;
    }
    
    lua_pushboolean(L, true);
    return 1;
}

//input is the udid string
static int Disconnect(lua_State* L) {
    uint16_t port;
    if(lua_isnumber(L, -1)) {
        port = lua_tonumber(L, -1);
        lua_pop(L, 1);
    } else {
        TypeError(2, "Disconnect", "Number", L);
        return 0;
    }

    std::string udid;
    if(lua_isstring(L, 1)) {
        udid = lua_tostring(L, 1);
        lua_pop(L, 1);
    } else {
        TypeError(1, "Disconnect", "String", L);
        return 0;
    }
    
    if(DisconnectDevice(udid.data(), port)) {
        lua_pushboolean(L, true);
    } else {
        lua_pushboolean(L, false);
    }

    return 1;
}

//send data to specific udid/device
//return the size of data actually sent
static int Send(lua_State* L) {
    const char* udid;
    int port;
    const char* sent_data;
    size_t len = 0;
    
    if(lua_isstring(L, 1)) {
        udid = lua_tostring(L, 1);
    } else {
        TypeError(1, "Send", "String", L);
        return 0;
    }
    
    if(lua_isnumber(L, 2)) {
        port = lua_tonumber(L,2);
    } else {
        TypeError(2, "Send", "Number", L);
        return 0;
    }

    if(lua_isstring(L, 3)) {
        //all package is string
        sent_data = luaL_tolstring(L, 3, &len);
        //printf("data size %zu\n", len);
    } else {
        TypeError(3, "Send", "String", L);
        return 0;
    }

    lua_pop(L, 3);
    
    ConnectID cnt_id(udid, port);

    auto iter = g_connect_id_map.find(cnt_id);
    if(iter != g_connect_id_map.end()) {
        uint32_t sent_bytes = 0;        
        idevice_error_t err = idevice_connection_send(iter->second, sent_data, len, &sent_bytes);
        printf("%d bytes data sent\n", sent_bytes);
        
        if(err != IDEVICE_E_SUCCESS) {
            return 0;
        } else {
            lua_pushnumber(L, sent_bytes);
            return 1;
        }
    } else {
        printf("no connection available for device %s and port %d\n", udid, port);
    }
    
    return 0;
}

//receive data from specific udid/device
const int MAX_BUFFER_SIZE = 64*1024;
char recv_buffer[MAX_BUFFER_SIZE];
static int Recv(lua_State* L)
{
    std::string udid;
    uint16_t port;
    float timeout;

    if(lua_isstring(L, 1)) {
        udid = lua_tostring(L, 1);
    } else {
        printf("first arg should be string\n");
        return 0;
    }

    if(lua_isnumber(L, 2)) {
        port = lua_tonumber(L, 2);
    } else {
        TypeError(2, "Recv", "Number", L);
        return 0;
    }

    if(lua_isnumber(L, 3)) {
        timeout = lua_tonumber(L, 3);
    } else {
        TypeError(3, "Recv", "Number", L);
        return 0;
    }
    
    lua_pop(L, 2);

    auto iter = g_connect_id_map.find(ConnectID(udid, port));
    if(iter != g_connect_id_map.end()) {
        uint32_t recv_bytes = 0;
        idevice_connection_receive_timeout(iter->second, &recv_buffer[0], MAX_BUFFER_SIZE, &recv_bytes, timeout);
        if(recv_bytes == 0) {
            return 0;
        } else {
            std::string data_s(recv_buffer, recv_bytes);
            //lua_pushstring(L, data_s.data());
            lua_pushlstring(L, data_s.data(), recv_bytes);
            return 1;
        }
    } else {
        printf("no connection available for device %s and port %d\n", udid.data(), port);
    }
    return 0;
}

//clean some mess up
static int Release(lua_State* L)
{
    auto connection_iter = g_connect_id_map.begin();
    for(;connection_iter != g_connect_id_map.end(); ++connection_iter) {
        idevice_disconnect(connection_iter->second);
    }
    g_connect_id_map.clear();

    auto devices_iter = g_device_map.begin();
    for(;devices_iter != g_device_map.end(); ++devices_iter) {
        idevice_free(devices_iter->second);
    }
    g_device_map.clear();
    
    return 0;
}

static int FreeDevices(lua_State* L)
{
    char **device_names = nullptr;
    int device_count = 0;
    
    idevice_error_t err = idevice_get_device_list(&device_names, &device_count);
    if(err == IDEVICE_E_SUCCESS)
    {
        idevice_device_list_free(device_names);
        printf("free device %s\n", device_names[0]);
    }
    
    return 0;
}

static const struct luaL_Reg lua_lib[] =
{
    {"GetDevices", GetDevices},
    {"Connect", Connect},
    {"Disconnect", Disconnect},
    {"Send", Send},
    {"Recv", Recv},
    {"Release", Release},
    {"FreeDevices", FreeDevices},
    {NULL, NULL},
};

int luaopen_libimobiledevicelua(lua_State* L)
{
    luaL_newlib(L, lua_lib);
    return 1;
}
