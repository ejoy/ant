--luacheck: ignore self
local ecs = ...
local world = ecs.world

local math = import_package "ant.math"
local ms = math.stack
local mu = math.util
local bgfx = require "bgfx"

--[@ view rect
ecs.component "view_rect"
	.x "real" (0)
	.y "real" (0)
	.w "real" (1)
	.h "real" (1)

local view_rect_sys = ecs.system "view_rect_system"

function view_rect_sys:update()
	for _, eid in world:each("camera") do
		local entity = world[eid]
		local vid = entity.camera.viewid
		if vid ~= nil then
			local vr = entity.view_rect
			bgfx.set_view_rect(vid, vr.x, vr.y, vr.w, vr.h)
		end
	end
end
--@]

--[@ clear component
local clear_comp = ecs.component "clear_component"
    .color "int" (0x303030ff)
    .depth "int" (1)
    .stencil "int" (0)

function clear_comp:init()
    self.clear_color = true
    self.clear_depth = true
	self.clear_stencil = true
	return self
end
--@]

--[@	clear system
local vp_clear_sys = ecs.system "clear_system"
function vp_clear_sys:update()
	for _, eid in world:each("camera") do
		local entity = world[eid]
		local camera = entity.camera
		local vid = camera.viewid

		if vid then			
			local cc = entity.clear_component
			local state = ''
			if cc.clear_color then
				state = state .. "C"
			end
			if cc.clear_depth then
				state = state .. "D"
			end
		
			if cc.clear_stencil then
				state = state .. "S"
			end
			if state ~= '' then
				bgfx.set_view_clear(vid, state, cc.color, cc.depth, cc.stencil)
			end
		end
    end
end
--@]


--[@ view system
local view_sys = ecs.system "view_system"
view_sys.depend "clear_system"
view_sys.depend "view_rect_system"

function view_sys:update()	
	for _, eid in world:each("camera") do
		local entity = world[eid]
		local camera = entity.camera
		local vid = camera.viewid
		local view, proj = mu.view_proj_matrix(entity)
		bgfx.set_view_transform(vid, view, proj)
	end
end
--@]