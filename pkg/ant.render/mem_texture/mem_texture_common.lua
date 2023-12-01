local ecs       = ...
local world     = ecs.world
local w         = world.w
local ivs		= ecs.require "ant.render|visible_state"
local math3d    = require "math3d"
local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local iom       = ecs.require "ant.objcontroller|obj_motion"
local icamera	= ecs.require "ant.camera|camera"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local ig        = ecs.require "ant.group|group"
local R         = world:clibs "render.render_material"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local hwi       = import_package "ant.hwi"
local itimer	= ecs.require "ant.timer|timer_system"
local mc        = import_package "ant.math".constant

local lastname = "mem_texture_static"

local m = {
    MEM_TEXTURE_STATIC_VIEWID       = hwi.viewid_get "mem_texture_static",
    STATIC_OBJ_NAME                 = "mem_texture_static_obj",
    STATIC_QUEUE_NAME               = "mem_texture_static_queue",
    MEM_TEXTURE_DYNAMIC_VIEWIDS     = setmetatable({}, {
        __index = function(t,name)
            local viewid = hwi.viewid_get(name)
            if viewid then
                t[name] = viewid
            else
                t[name] = hwi.viewid_generate(name, lastname) 
            end
            return t[name] 
        end
    }),
    DYNAMIC_OBJ_NAME                = "mem_texture_dynamic_obj",
    DYNAMIC_OBJS                    = {},
    DYNAMIC_QUEUE_NAME              = "mem_texture_dynamic_queue",
    DYNAMIC_QUEUES                  = {},
    ACTIVE_MASKS                    = {},
    DEFAULT_RT_WIDTH                = 512,
    DEFAULT_RT_HEIGHT               = 512,
    RB_FLAGS  = sampler{
        MIN =   "LINEAR",
        MAG =   "LINEAR",
        U   =   "CLAMP",
        V   =   "CLAMP",
        RT  =   "RT_ON",
    },
    DEFAULT_EXTENTS                 = math3d.mark(math3d.vector(50, 50, 50)),
    DEFAULT_LENGTH                  = math3d.length(math3d.mul(1.6, math3d.vector(50, 50, 50))),
    DISTANCE                        = {}
}

return m
