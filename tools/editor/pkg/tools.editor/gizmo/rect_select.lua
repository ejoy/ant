local ecs 	= ...
local world = ecs.world
local w 	= world.w
local irender	= ecs.require "ant.render|render"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local iviewport = ecs.require "ant.render|viewport.state"
local math3d    = require "math3d"

local m = {}

local function create_select_eid(color, texture)
    return world:create_entity {
        policy = {
            "ant.render|dynamic2d",
        },
        data = {
            scene = {t={0, 0, 0}},
            material = "/pkg/ant.resources/materials/default2d_blend.material",
            dynamicquad = {
                texture = texture,
                width = 1,
                height = 1,
                clear = color
            },
            visible_masks   = "",
            visible     = false
        }
    }
end

function m:init()
    self.visible = false
    self.rect_start_x = -1
    self.rect_start_y = -1
    self.rect_end_x = -1
    self.rect_end_y = -1
    self.frame_size = 2
	self.bg_eid = create_select_eid({150, 180, 210, 125}, "/pkg/tools.editor/resource/textures/rect_select_bg.texture")
	self.fg_eid = create_select_eid({100, 100, 100, 125}, "/pkg/tools.editor/resource/textures/rect_select_fg.texture")
end

function m:draw(x, y)
	self.rect_end_x = x
	self.rect_end_y = y
	local width = math.abs(self.rect_end_x - self.rect_start_x)
	local height = math.abs(self.rect_end_y - self.rect_start_y)
	if width < 1 or height < 1 then
		return
	end
	local pos_x = self.rect_start_x < self.rect_end_x and self.rect_start_x or self.rect_end_x
	local pos_y = self.rect_start_y < self.rect_end_y and self.rect_start_y or self.rect_end_y

	local e <close> = world:entity(self.bg_eid)
	iom.set_position(e, math3d.vector{pos_x, pos_y, 0})
	iom.set_scale(e, math3d.vector{width, height, 1})

	local offset = width > (2 * self.frame_size) and self.frame_size or 0
	local e2 <close> = world:entity(self.fg_eid)
	iom.set_position(e2, math3d.vector{pos_x + offset, pos_y + offset, 0})
	iom.set_scale(e2, math3d.vector{width - 2 * offset, height - 2 * offset, 1})
	local wr = 1.0 / iviewport.device_viewrect.w
	local hr = 1.0 / iviewport.device_viewrect.h
	local frustum = {
		l = pos_x * wr * 2.0 - 1.0,
		r = (pos_x + width) * wr * 2.0 - 1.0,
		t = (1.0 - pos_y * hr) * 2.0 - 1.0,
		b = (1.0 - (pos_y + height) * hr) * 2.0 - 1.0,
		n = 0.1,
		f = 500,
	}
	world:pub {"SelectFrustum", frustum}
	if not self.visible then
		self:set_visible(true)
	end
end

function m:set_visible(visible)
	self.visible = visible
	local e <close> = world:entity(self.bg_eid)
	irender.set_visible(e, visible)
	local e2 <close> = world:entity(self.fg_eid)
	irender.set_visible(e2, visible)
end

function m:start(x, y)
	local e <close> = world:entity(self.bg_eid)
	iom.set_position(e, math3d.vector{x, y, 0})
	iom.set_scale(e, math3d.vector{1, 1, 1})
	local e2 <close> = world:entity(self.fg_eid)
	iom.set_position(e2, math3d.vector{x, y, 0})
	iom.set_scale(e2, math3d.vector{1, 1, 1})
	self.rect_start_x = x
	self.rect_start_y = y
end

function m:finish()
	self:set_visible(false)
end

return m