local ecs = ...
local world = ecs.world
local assetmgr = require "asset"

local platform = require "platform"
local timer = world:interface "ant.timer|timer"

local gc = ecs.system "asset_gc"
gc.require_system "end_frame"
gc.require_interface "ant.timer|timer"

local expiration<const> = 1000
local lasttime

local function need_check()
    local curtime = timer.cur_time()
    if (curtime - lasttime) > expiration then
        lasttime = curtime
        return true
    end
end

local function resource_type(reskey)
    return reskey:match "%.([%w_]+)$"
end

function gc:init()
    lasttime = timer.current()
end

function gc:update()
    if not need_check() then
        return 
    end

    local size_300m<const> = 1024 * 1024 * 300

    local memoryused = platform.info "memory"
    if memoryused > size_300m then
        local t = {}
        local profiles = assetmgr.resource_profiles()
        local vaildtypes = {
            mesh = true,
            material = true,
            ozz = true,
            hierarchy = true,
            pbrm = true,
            sm = true,
        }
        for reskey, profile in pairs(profiles) do
            local restype = resource_type(reskey)
    
            if vaildtypes[restype] then
                t[#t+1] = {reskey, profile}
            end
        end
    
        table.sort(t, function(lhs, rhs)
            return lhs[2].counter < rhs[2].counter
        end)

        local r = t[1]
        local reskey = r[1]
        local profile = r[2]

        assetmgr.unload(reskey)

        log.info(string.format("unload resource:%s, sizebytes:%d", reskey, profile.sizebytes))
    end
end