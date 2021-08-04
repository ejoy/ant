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

local function has_filter_tag(t, filter_names)
	for _, fn in ipairs(filter_names) do
		if fn == t then
			return true
		end
	end
end

w:register{name = "filter_result", type = "lua"}

function render_sys:update_filter()
	w:clear "filter_result"
    for e in w:select "render_object_update render_object:in filter_result:temp" do
        local ro = e.render_object
        local state = ro.entity_state
		local st = ro.fx.setting.surfacetype

		local filter_result = {}
		for qe in w:select "queue_name:in filter_names:in" do
			local qn = qe.queue_name
			local tag = ("%s_%s"):format(qn, st)

			if has_filter_tag(tag, qe.filter_names) then
				local synctag = tag .. "?out"
				for fe in w:select(tag .. " primitive_filter:in") do
					local pf = fe.primitive_filter
					local mask = ies.filter_mask(pf.filter_type)
					local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

					local add = ((state & mask) ~= 0) and ((state & exclude_mask) == 0)
					e[tag] = add
					if add then
						filter_result[tag] = true
					end
				end
				w:sync(synctag, e)
			end
		end
		e.filter_result = filter_result
    end
end

local function submit_render_objects(viewid, filternames, culltag)
	for idx, fn in ipairs(filternames) do
		local s = culltag and
			("%s %s:absent render_object:in filter_material?in"):format(fn, culltag[idx]) or
			("%s render_object:in filter_material?in"):format(fn)

		for e in w:select(s) do
			local fm = e.filter_material
			irender.draw(viewid, e.render_object, fm and fm[fn] or nil)
		end
	end
end

function render_sys:render_submit()
	for qe in w:select "visible camera_eid:in render_target:in filter_names:in cull_tag?in" do
		--TODO: should keep camera always vaild
        local camera = icamera.find_camera(qe.camera_eid)
		if camera then
			local rt = qe.render_target
			local viewid = rt.viewid

			bgfx.touch(viewid)
			bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
			local filternames, culltag = qe.filter_names, qe.cull_tag

			submit_render_objects(viewid, filternames, culltag)
		end
    end
end

local s = ecs.system "end_filter_system"
function s:end_filter()
	w:clear "render_object_update"
end