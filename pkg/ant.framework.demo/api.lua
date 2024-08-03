local rhwi = import_package "ant.hwi"
local bgfx = require "bgfx"

return function (ecs, args)
	local world = ecs.world
	local w = world.w
	
	local api = {}
	
	api.camera_ctrl = ecs.require "camera_ctrl"

	local keyboard = ecs.require "keyboard"
	local mouse = ecs.require "mouse"
	api.key_press = keyboard.key_press
	api.key_callback = keyboard.key_callback
	api.mouse_callback = mouse.mouse_callback
	mouse.mouse_sync(api)
	
	local gesture = ecs.require "gesture"
	api.gesture_listen = gesture.listen
	
	function api.show_profile(enable)
	    rhwi.set_profie(enable)
	end

	function api.import_prefab ( name )
		world:create_instance { prefab = name }
	end
	
	function api.maxfps(fps)
		bgfx.maxfps(fps)
	end
	
	local primitive = require "primitive"
	function api.primitive (name, obj)
		return primitive.new(world, name, obj)
	end
	
	local prefab = require "prefab"
	function api.prefab (name, obj)
		return prefab.new(world, name, obj)
	end
	
	function api.remove(obj)
		local eid = obj and obj.eid
		if eid == nil then
			return
		end
		local inst = obj.inst
		setmetatable(obj.material, nil)
		setmetatable(obj, nil)
		if inst then
			world:remove_instance(inst)
		elseif eid then
			world:remove_entity(eid)
		end
	end

	if args.setting then
		local serialize = import_package "ant.serialize"
		api.setting = serialize.load(args.setting)
	end
	
	local gui = ecs.require "gui"
	
	if api.setting then
		local fontname = api.setting.font
		if fontname then
			gui.import_font(fontname)
		end
	end
	
	api.gui_open = gui.open
	api.gui_listen = gui.on_message
	api.gui_send = gui.send
	api.gui_call = gui.call
	
	return api
end