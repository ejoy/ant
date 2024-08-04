local ecs       = ...
local world     = ecs.world
local w         = world.w

local icamera	= ecs.require "ant.camera|camera"
local irq		= ecs.require "ant.render|renderqueue"
local math3d	= require "math3d"
local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util
local bgfx		= require "bgfx"

local debug_text_system  = ecs.system "debug_text_system"

local text_buffer = {}

function debug_text_system:frame_update()
	if w:count "debug_text" == 0 then
		return
	end
	local ce <close> = world:entity(irq.main_camera())
	local vpmat = icamera.calc_viewproj(ce)
	local mqvr = irq.view_rect "main_queue"
	local world_to_screen = mu.world_to_screen
	
	for e in w:select "debug_text eid:in scene:in" do
		local pos = math3d.index(e.scene.worldmat, 4)
		local screen_pos = world_to_screen(vpmat, mqvr, pos)
		local x, y = math3d.index(screen_pos, 1, 2)
		bgfx.dbg_text_print(x // 8, y // 16, 0x03, text_buffer[e.eid])
	end
	w:clear "debug_text"
	text_buffer = {}
end


local debug_text = {}

function debug_text.print(eid, str)
	text_buffer[eid] = str
	w:access(eid, "debug_text", true)
end

return debug_text

