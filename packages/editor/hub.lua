local os = require "os"
local task = require "task"
local thread = require "thread"
local hub = {   
                _inited = false
            }

local default_config = {
    interval = 0.03
}

local function init()
    if hub._inited then return end
    hub._inited = true
    hub._channel_update = {}
    hub._channel_one_func = {}  -- subscibe
    hub._channel_mult_func = {} -- subscibe_mult
    hub._channel_cfg = {}
    hub._channel_msg = {}
    hub._channel_msg_num = {}
    local function update_hub()
        local update_funcs = hub._channel_update
        for _,func in pairs(update_funcs) do
            func()
        end
    end
    hub._update = update_hub
    task.safe_loop(update_hub)
end 

local function shallow_copy_array(arr,arr_size)
    arr_size = arr_size or #arr
    local copy = {}
    for i = 1,arr_size do
        copy[i] = arr[i]
    end
    return copy
end

local function init_channel(channel)
    init()
    if hub._channel_cfg[channel] then
        return
    end
    hub._channel_one_func[channel] = {}
    hub._channel_mult_func[channel] = {}
    local cfg = setmetatable({},{__index = default_config})
    hub._channel_cfg[channel] = cfg
    local msg = {}
    hub._channel_msg[channel] = {}
    hub._channel_msg_num[channel] = 0
    local last_update_time = os.clock()
    local function update()
        local interval = cfg.interval
        local cur_time = os.clock()
        -- print("-----channel update",cur_time - last_update_time)
        if cur_time - last_update_time >= interval then
            -- print(".")
            local msg_num = hub._channel_msg_num[channel]
            hub._channel_msg_num[channel] = 0
            if msg_num > 0 then
                local msgs = hub._channel_msg[channel]
                hub._channel_msg[channel] = {}
                local msg_obj = msgs[msg_num]
                local msg_tbl = thread.unpack(msg_obj)
                local one = hub._channel_one_func[channel]
                for target,funcs in pairs(one) do
                    if target == hub then
                        for _,func in ipairs(funcs) do
                            func(table.unpack(msg_tbl))
                        end
                    else
                        for _,func in ipairs(funcs) do
                            func(target,table.unpack(msg_tbl))
                        end
                    end
                end
                local mult = hub._channel_mult_func[channel]
                local msg_copy = shallow_copy_array(msg_tbl)
                for target,funcs in pairs(mult) do
                    if target == hub then
                        for _,func in ipairs(funcs) do
                            func(msg_copy)
                        end
                    else
                        for _,func in ipairs(funcs) do
                            func(target,msg_copy)
                        end
                    end
                end
                
               
            end
            last_update_time = cur_time
        end
    end
    hub._channel_update[channel] = update
end


--only get newest message in one intercal
function hub.subscibe(channel,func,func_target)
    assert(func,"func is nil")
    assert(channel,"channel is nil")
    print("subscibe:",channel)
    init_channel(channel)
    func_target = func_target or hub
    local funcs = hub._channel_one_func[channel]
    funcs[func_target] = funcs[func_target] or setmetatable({}, {__mode = "k"})
    local func_in_target = funcs[func_target]
    for _,v in ipairs(func_in_target) do
        if v == func then
            return
        end
    end
    table.insert(func_in_target,func)
end

function hub.unsubscibe(channel,func,func_target)
    assert(func,"func is nil")
    assert(channel,"channel is nil")
    if ( not hub._inited ) or ( not hub._channel_cfg[channel] ) then
        return
    end
    func_target = func_target or hub
    local funcs = hub._channel_one_func[channel]
    local func_in_target = funcs[func_target]
    if not func_in_target then
        return
    end
     for i,v in ipairs(func_in_target) do
        if v == func then
            table.remove(func_in_target,i)
            return
        end
    end
end

--get all message in one intercal
function hub.subscibe_mult(channel,func,func_target)
    assert(func,"func is nil")
    assert(channel,"channel is nil")
    init_channel(channel)
    func_target = func_target or hub
    local funcs = hub._channel_mult_func[channel]
    funcs[func_target] = funcs[func_target] or setmetatable({}, {__mode = "k"})
    local func_in_target = funcs[func_target]
    for _,v in ipairs(func_in_target) do
        if v == func then
            return
        end
    end
    table.insert(func_in_target,func)
end

function hub.unsubscibe_mult(channel,func,func_target)
    assert(func,"func is nil")
    assert(channel,"channel is nil")
    if ( not hub._inited ) or ( not hub._channel_cfg[channel] ) then
        return
    end
    func_target = func_target or hub
    local funcs = hub._channel_mult_func[channel]
    local func_in_target = funcs[func_target]
    if not func_in_target then
        return
    end
     for i,v in ipairs(func_in_target) do
        if v == func then
            table.remove(func_in_target,i)
            return
        end
    end
end

function hub.unsubscibe_all_by_target(func_target)
    assert(func_target)
    for channel,_ in pairs(hub._channel_cfg ) do
        local funcs_mult = hub._channel_mult_func[channel]
        funcs_mult[func_target] = nil
        local funcs_one = hub._channel_one_func[channel]
        funcs_one[func_target] = nil
    end
end

--arg:{interval = xx}
function hub.set_channel(channel,args)
    init_channel(channel)
    local cfg = hub._channel_cfg[channel]
    for k,v in pairs(args) do
        cfg[k] = v
    end
end

function hub.publish(channel,...)
    assert(channel,"channel is nil")
    local args = {...}
    print("publish:",channel,...)
    init_channel(channel)
    local msg_num = hub._channel_msg_num[channel]
    local args_obj = thread.pack(args)
    hub._channel_msg[channel][msg_num+1] = args_obj
    hub._channel_msg_num[channel] = msg_num+1
end

return hub