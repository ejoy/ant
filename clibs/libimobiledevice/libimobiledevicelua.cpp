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

extern "C" int luaopen_libimobiledevicelua(lua_State* L);

std::map<std::string, idevice_t> g_device_map;
std::map<std::string, idevice_connection_t> g_connection_map;
bool is_init = false;

bool DisconnectDevice(const char* udid)
{
    auto iter = g_connection_map.find(udid);
    if(iter == g_connection_map.end())
        return true;
    
    idevice_error_t err = idevice_disconnect(iter->second);
    if(err == IDEVICE_E_SUCCESS)
    {
        g_connection_map.erase(udid);
        return true;
    }
    
    return false;
}

void EventCallback(const idevice_event_t* event, void* user_data)
{
    const char* event_device_id = event->udid;
    if(event_device_id)
    {
        enum idevice_event_type event_type = event->event;
        switch (event_type) {
            case IDEVICE_DEVICE_ADD:
            {
                auto iter = g_device_map.find(event_device_id);
                if(iter == g_device_map.end())
                {
                    printf("%s connected\n", event_device_id);
                    //add device
                    idevice_t new_device;
                    idevice_error_t err = idevice_new(&new_device, event_device_id);
                    if(err == IDEVICE_E_SUCCESS)
                    {
                        g_device_map.emplace(event_device_id, new_device);
                    }
                    else
                    {
                        printf("failed to create %s device, error code %d \n", event_device_id, err);
                    }
                }
                
                //need to call the lua function
            }
                break;
            case IDEVICE_DEVICE_REMOVE:
            {
                DisconnectDevice(event_device_id);
                g_device_map.erase(event_device_id);
                
                printf("%s disconnected\n", event_device_id);
            }
                break;
            case IDEVICE_DEVICE_PAIRED:
            {
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
void Init()
{
    char **device_names = nullptr;
    int device_count = 0;
    
    idevice_error_t err = idevice_get_device_list(&device_names, &device_count);
    
    if(err == IDEVICE_E_SUCCESS)
    {
        for(int i = 0; i < device_count; ++i)
        {
            idevice_t new_device;
            err = idevice_new(&new_device, device_names[i]);
            if(err != IDEVICE_E_SUCCESS)
            {
                printf("fail to create new device with udid %s\n", device_names[i]);
                continue;
            }
            else
            {
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

static int GetDevices(lua_State* L)
{
    if(!is_init)
        Init();
    
    lua_newtable(L);
    
    auto iter = g_device_map.begin();

    int count = 1;
    for(; iter != g_device_map.end(); ++iter)
    {
        lua_pushstring(L, iter->first.data());
        lua_rawseti(L, -2, count);
        
        ++count;
    }
    
    return 1;
}

//input is the udid string, and port
static int Connect(lua_State* L)
{
    std::string udid;
    int port;    //by default
    if(lua_isstring(L, 1))
    {
        //get the udid string
        udid = lua_tostring(L, 1);
 //       printf("udid %s\n", udid.data());
    }
    else
    {
        printf("input invalid, first arg should be string\n");
        lua_pushboolean(L, false);
        return 1;
    }
    
    if(lua_isnumber(L, 2))
    {
        port = lua_tonumber(L, 2);
    }
    else
    {
        printf("input invalid, second arg should be number\n");
        lua_pushboolean(L, false);
        return 1;
    }
    
    
    auto iter = g_device_map.find(udid);
    if(iter == g_device_map.end())
    {
        printf("udid: %s not found\n", udid.data());
        lua_pushboolean(L, false);
        return 1;
    }
    
    idevice_connection_t new_connection;
    idevice_error_t err = idevice_connect(iter->second, port, &new_connection);
    if(err == IDEVICE_E_SUCCESS)
    {
        g_connection_map.emplace(udid, new_connection);
        printf("new connection created with udid: %s and port: %d\n", udid.data(), port);
    }
    else
    {
     //   printf("fail to create connection, udid: %s, port: %d\n", udid.data(), port);
        lua_pushboolean(L, false);
        return 1;
    }
    
    lua_pushboolean(L, true);
    return 1;
}

//input is the udid string
static int Disconnect(lua_State* L)
{
    std::string udid;
    if(lua_isstring(L, 1))
    {
        udid = lua_tostring(L, 1);
        if(DisconnectDevice(udid.data()))
        {
            lua_pushboolean(L, true);
        }
        else
        {
            lua_pushboolean(L, false);
        }
    }
    else
    {
        lua_pushboolean(L, false);
        printf("input invalid, arg should be string\n");
    }
    
    return 1;
}

//send data to specific udid/device
//return the size of data actually sent
static int Send(lua_State* L)
{
    const char* udid;
    const char* sent_data;
    size_t len = 0;
    
    if(lua_isstring(L, 1))
    {
        udid = lua_tostring(L, 1);
    }
    else
    {
        lua_pushnumber(L, 0);
        return 1;
    }
    
    if(lua_isstring(L, 2))
    {
        //all package is string
        sent_data = luaL_tolstring(L, 2, &len);
        //printf("data size %zu\n", len);
    }
    else
    {
        lua_pushnumber(L, 0);
        return 1;
    }
    
    auto iter = g_connection_map.find(udid);
    if(iter != g_connection_map.end())
    {
        uint32_t sent_bytes = 0;

        
        idevice_error_t err = idevice_connection_send(iter->second, sent_data, len, &sent_bytes);
        printf("%d bytes data sent\n", sent_bytes);
        
        if(err != IDEVICE_E_SUCCESS)
        {
            lua_pushnumber(L, 0);
            return 1;
        }
        else
        {
            lua_pushnumber(L, sent_bytes);
            return 1;
        }
    }
    else
    {
        printf("no connection available for %s\n", udid);
    }
    
    lua_pushnumber(L, 0);
    return 1;
}

//receive data from specific udid/device
const int MAX_BUFFER_SIZE = 64*1024;
char recv_buffer[MAX_BUFFER_SIZE];
static int Recv(lua_State* L)
{
    std::string udid;
    if(lua_isstring(L, 1))
    {
        udid = lua_tostring(L, 1);
        
        auto iter = g_connection_map.find(udid);
        if(iter != g_connection_map.end())
        {
            uint32_t recv_bytes = 0;
            idevice_connection_receive(iter->second, &recv_buffer[0], MAX_BUFFER_SIZE, &recv_bytes);
        //    printf("%d bytes data received\n", recv_bytes);
            if(recv_bytes == 0)
            {
                return 0;
            }
            else
            {
                std::string data_s(recv_buffer, recv_bytes);
                //lua_pushstring(L, data_s.data());
                lua_pushlstring(L, data_s.data(), recv_bytes);
                return 1;
            }
        }
        else
        {
            printf("no connection available for %s\n", udid.data());
        }
        
        return 0;
    }
    
    return 0;
}

//clean some mess up
static int Release(lua_State* L)
{
    auto connection_iter = g_connection_map.begin();
    for(; connection_iter != g_connection_map.end(); ++connection_iter)
    {
        idevice_disconnect(connection_iter->second);
    }
    g_connection_map.clear();
    
    auto devices_iter = g_device_map.begin();
    for(;devices_iter != g_device_map.end(); ++devices_iter)
    {
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
