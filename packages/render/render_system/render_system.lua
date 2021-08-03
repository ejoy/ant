local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local isp		= world:interface "ant.render|system_properties"
local irender	= world:interface "ant.render|irender"
local ies		= world:interface "ant.scene|ientity_state"
local icamera	= world:interface "ant.camera|camera"
local render_sys = ecs.system "render_system"

function render_sys:update_system_properties()
	isp.update()
end

local function has_filter_tag(queuename, t)
	for qe in w:select (queuename .. " filter_names:in") do
		for _, fn in ipairs(qe.filter_names) do
			if fn == t then
				return true
			end
		end
	end
end

function render_sys:update_filter()
    for e in w:select "render_object_update render_object:in" do
        local ro = e.render_object
        local state = ro.entity_state
		local st = ro.fx.setting.surfacetype

		for _, qn in ipairs{"main_queue", "blit_queue"} do
			local tag = ("%s_%s"):format(qn, st)
			
			if has_filter_tag(qn, tag) then
				local synctag = tag .. "?out"
				for fe in w:select(tag .. " primitive_filter:in") do
					local pf = fe.primitive_filter
					local mask = ies.filter_mask(pf.filter_type)
					local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

					local add = ((state & mask) ~= 0) and ((state & exclude_mask) == 0)
					e[tag] = add
				end
				w:sync(synctag, e)
			end
		end
    end
end

function render_sys:render_submit()
	for v in w:select "visible camera_eid:in render_target:in" do
        local rt = v.render_target
        local viewid = rt.viewid
        local camera = icamera.find_camera(v.camera_eid)
		if camera then
			bgfx.touch(viewid)
			bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
		end
    end

	--TODO: should put all render queue here
	for _, qn in ipairs{"main_queue", "blit_queue"} do
		for qe in w:select(qn .. " visible camera_eid:in render_target:in filter_names:in cull_tag?in") do
			local viewid = qe.render_target.viewid
			local filternames, culltag = qe.filter_names, qe.cull_tag
			if culltag then
				for idx, fn in ipairs(filternames) do
					for e in w:select(("%s %s:absent render_object:in"):format(fn, culltag[idx])) do
						irender.draw(viewid, e.render_object)
					end
				end
			else
				for _, fn in ipairs(filternames) do
					for e in w:select(("%s render_object:in"):format(fn)) do
						irender.draw(viewid, e.render_object)
					end
				end
			end
		end
	end
end

local s = ecs.system "end_filter_system"
function s:end_filter()
	w:clear "render_object_update"
end