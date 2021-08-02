local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local isp		= world:interface "ant.render|system_properties"
local irender	= world:interface "ant.render|irender"
local ipf		= world:interface "ant.scene|iprimitive_filter"
local ies		= world:interface "ant.scene|ientity_state"
local icamera	= world:interface "ant.camera|camera"
local render_sys = ecs.system "render_system"

function render_sys:update_system_properties()
	isp.update()
end

function render_sys:update_filter()
    for e in w:select "render_object_update render_object:in name:in" do
        local ro = e.render_object
        local state = ro.entity_state
		local st = ro.fx.setting.surfacetype

		for _, qn in ipairs{"main_queue", "blit_queue"} do
			local tag = ("%s_%s?out"):format(qn, st)
			for vv in w:select(tag .. " primitive_filter:in") do
				local pf = vv.primitive_filter
				local mask = ies.filter_mask(pf.filter_type)
				local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

				local add = ((state & mask) ~= 0) and ((state & exclude_mask) == 0)
				e[tag] = add
			end
			w:sync(tag, e)
		end
    end
end

function render_sys:render_submit()
	for v in w:select "visible camera_eid:in render_target:in" do
        local rt = v.render_target
        local viewid = rt.viewid
        local camera = icamera.find_camera(v.camera_eid)
        bgfx.touch(viewid)
        bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
    end

	--TODO: should put all render queue here
	for _, qn in ipairs{"main_queue", "blit_queue"} do
		for e in w:select(qn .. " visible render_target:in") do
			local viewid = e.render_target.viewid
			local culltag = qn .. "_cull"
			for _, ln in ipairs(ipf.layers(qn)) do
				local s = ("%s_%s %s:absent render_object:in name:in"):format(qn, ln, culltag)
				for ee in w:select(s) do
					irender.draw(viewid, ee.render_object)
				end
			end
			w:clear(culltag)
		end
	end
end

local s = ecs.system "end_filter_system"
function s:end_filter()
	w:clear "render_object_update"
end