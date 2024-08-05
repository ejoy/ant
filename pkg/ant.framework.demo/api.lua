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
	api.mouse_state = {}
	mouse.mouse_sync(api.mouse_state)
	
	local gesture = ecs.require "gesture"
	api.gesture_listen = gesture.listen

	local profile_items = "fps time system view encoder"
	
	bgfx.show_profile(profile_items, args.profile)
	function api.profile_enable(enable)
		if enable then
			bgfx.show_profile(profile_items, false)
		else
			bgfx.show_profile(profile_items, true)
		end
	end

	function api.show_debug(enable)
		if enable then
			bgfx.set_debug "T"
		else
			bgfx.set_debug ""
		end
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
		local dtor = obj.__dtor
		if dtor then
			dtor(world, obj)
			setmetatable(obj.material, nil)
			setmetatable(obj, nil)
			obj.__dtor = nil
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
	
	local debug_text = ecs.require "ant.debug_text|debug_text"
	
	function api.print(obj, str)
		local eid = obj.eid
		if eid then
			debug_text.print(eid, str)
		end
	end
	
	return api
end