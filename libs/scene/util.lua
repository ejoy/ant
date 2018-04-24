local ecs = require "ecs"
local task = require "editor.task"

local elog = require "editor.log"
local db = require "debugger"

local util = {}
util.__index = util

local world = nil

function util.start_new_world(input_queue)
	world = ecs.new_world {
		modules = { 
			assert(loadfile "libs/inputmgr/message_system.lua"),
			assert(loadfile "libs/render/constant_system.lua"),
			assert(loadfile "libs/render/add_entity_system.lua"),	-- for test
			assert(loadfile "libs/render/editor/general_editor_entities.lua"),	-- editor			
			assert(loadfile "libs/render/window_component.lua"),
			assert(loadfile "libs/render/components/general.lua"),			
			assert(loadfile "libs/render/math3d/math_component.lua"),			
			assert(loadfile "libs/render/camera/camera_component.lua"),
			assert(loadfile "libs/render/camera/camera_controller.lua"),
			assert(loadfile "libs/render/view_system.lua"),
			assert(loadfile "libs/render/entity_rendering_system.lua"),
			assert(loadfile "libs/render/pick/pickup_system.lua"),
			assert(loadfile "libs/render/pick/obj_trans_controller.lua"),
			assert(loadfile "libs/render/end_frame_system.lua"),
		},		
		update_bydepend = true,
		args = { mq = input_queue },
    }
    
	task.loop(world.update,	
	function (co, status)
		local trace = db.traceback(co)
		elog.print(status)
		elog.print("\n")
		elog.print(trace)
		elog.active_error()
    end)
    
    return world
end

return util