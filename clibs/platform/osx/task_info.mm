#include <lua.hpp>
#include <mach/mach.h>
#include <mach/message.h>
#include <mach/kern_return.h>
#include <mach/task_info.h>

int linfo(lua_State* L) {
    const char* lst[] = {"memory", NULL};
    int opt = luaL_checkoption(L, 1, NULL, lst);
    switch (opt) {
    case 0: {
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        task_vm_info_data_t data = {};
        kern_return_t error = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&data, &count);
        if (error != KERN_SUCCESS) {
            return luaL_error(L, "task_info error = %d", (int)error);
        }
        lua_pushinteger(L, (lua_Integer)data.phys_footprint);
        return 1;
    }
    default:
        return luaL_error(L, "invalid option");
    }
}
