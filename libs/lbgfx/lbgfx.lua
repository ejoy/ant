local require = import and import(...) or require

local bgfx = require "bgfx"
local framework = require "framework"

local ant = {}

local init_flag

function ant.init(args)
	assert(init_flag == nil)
	bgfx.set_platform_data(args)
	bgfx.init(args.renderer)
	ant.caps = bgfx.get_caps()
	init_flag = true
	framework.init_all()
end

function ant.shutdown()
	if init_flag then
		bgfx.shutdown()
	end
end

function ant.mainloop(f)
	iup.SetIdle(function ()
		local ok , err = xpcall(f, debug.traceback)
		if not ok then
			print(err)
			iup.SetIdle()
		end
		return iup.DEFAULT
	end)
end

return ant
