local ecs = ...
local world = ecs.world
local w = world.w

local isp		= world:interface "ant.render|system_properties"
local irender	= world:interface "ant.render|irender"
local ipf		= world:interface "ant.scene|iprimitive_filter"
local ies		= world:interface "ant.scene|ientity_state"
local render_sys = ecs.system "render_system"

function render_sys:update_system_properties()
	isp.update()
end

function render_sys:update_filter()
    for v in w:select "render_object_update render_object:in" do
        local ro = v.render_object
        local state = ro.entity_state
		for _, ln in ipairs(ipf.layers "main_queue") do
			for vv in w:select(ln .. " main_queue primitive_filter:in") do
				local pf = vv.primitive_filter
				local mask = ies.filter_mask(pf.filter_type)
				local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

				local add = ((state & mask) ~= 0) and ((state & exclude_mask) == 0)
				ipf.update_filter_tag("main_queue", ln, add, v)
			end
		end
    end
end

function render_sys:render_submit()
    for v in w:select "main_queue visible render_target:in" do
        local viewid = v.render_target.viewid
		for _, ln in ipairs(ipf.layers "main_queue") do
			for vv in w:select(ln .. " main_queue render_object:in main_queue_cull:absent") do
				irender.draw(viewid, vv.render_object)
			end
		end
		w:clear "main_queue_cull"
    end
end

