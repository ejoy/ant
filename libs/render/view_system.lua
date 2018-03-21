local ecs = ...
local world = ecs.world

local ru = require "render.util"
local cu = require "render.components.util"
local mu = require "math.util"
local bgfx = require "bgfx"

--[@ view rect
local view_rect_comp = ecs.component "view_rect"{
	x = 0, 
	y = 0, 
	w = 1, 
	h = 1,
}

local view_rect_sys = ecs.system "view_rect_system"

function view_rect_sys:update()
	
	ru.foreach_entity(world, {"viewid", "view_rect"},
	function (entity)
		local id = entity.viewid.id
		local vr = entity.view_rect
		bgfx.set_view_rect(id, vr.x, vr.y, vr.w, vr.h)
	end)
end
--@]

--[@ clear component
local clear_comp = ecs.component "clear_component"{
    color = 0x303030ff,
    depth = 1,
    stencil = 0,
}

function clear_comp:init()
    self.clear_color = true
    self.clear_depth = true
    self.clear_stencil = false
end
--@]

--[@	clear system
local vp_clear_sys = ecs.system "clear_system"
function vp_clear_sys:update()
    ru.foreach_entity(world, {"viewid", "clear_component"},
	function (entity) 
        local id = entity.viewid.id
        local cc = entity.clear_component
        local state = ""
        if cc.clear_color then
            state = state .. "C"
        end
        if cc.clear_depth then
            state = state .. "D"
        end

        if cc.clear_stencil then
            state = state .. "S"
		end
        bgfx.set_view_clear(id, state, cc.color, cc.depth, cc.stencil)
    end)
end
--@]


--[@ view system
local view_sys = ecs.system "view_system"
view_sys.singleton "math_stack"
view_sys.depend "clear_system"
view_sys.depend "view_rect_system"


local function update_frustum_from_aspect(rt, frustum)
	local aspect = rt.w / rt.h
	local tmp_h = frustum.t - frustum.b
	local tmp_hw = aspect * tmp_h * 0.5
	frustum.l = -tmp_hw
	frustum.r = tmp_hw
end

function view_sys:update()	
	ru.foreach_entity(world, {"position", "direction", "frustum", "view_rect"},
	function (entity)
		local view_mat = self.math_stack(entity.position.v, entity.direction.v, "Lm")

		local vr = entity.view_rect
		local frustum = assert(entity.frustum)
		update_frustum_from_aspect(vr, frustum)
		
		local proj_mat = mu.proj_v(self.math_stack, frustum)

		--local proj_mat = mu.proj_v(self.math_stack, frustum)
		bgfx.set_view_transform(entity.viewid.id, view_mat, proj_mat)
	end)
end
--@]