local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local isp		= ecs.import.interface "ant.render|isystem_properties"
local irender	= ecs.import.interface "ant.render|irender"
local ies		= ecs.import.interface "ant.scene|ifilter_state"
local icamera	= ecs.import.interface "ant.camera|camera"
local render_sys = ecs.system "render_system"

function render_sys:component_init()
	for e in w:select "INIT render_object:update filter_material:out render_object_update?out" do
		e.render_object = e.render_object or {}
		e.filter_material = {}
		e.render_object_update = true
	end
end

function render_sys:entity_init()
	w:clear "filter_created"
	for qe in w:select "INIT primitive_filter:in queue_name:in filter_created?out" do
		local pf = qe.primitive_filter
		local qn = qe.queue_name
		for i=1, #pf do
			local n = qn .. "_" .. pf[i]
			pf[i] = n
			w:register{name = n}
		end

		qe.filter_created = true
		w:sync("filter_created?out", qe)

		pf._DEBUG_filter_type = pf.filter_type
		pf.filter_type = ies.filter_mask(pf.filter_type)
		pf._DEBUG_excule_type = pf.exclude_type
		pf.exclude_type = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0
	end

	for e in w:select "INIT material_result:in render_object:in" do
		local ro = e.render_object
		local mr = e.material_result
		ro.fx			= mr.fx
		ro.properties	= mr.properties
		ro.state		= mr.state
		ro.stencil		= mr.stencil
	end
end

function render_sys:commit_system_properties()
	isp.update()
end

local function has_filter_tag(t, filter)
	for _, fn in ipairs(filter) do
		if fn == t then
			return true
		end
	end
end

function render_sys:update_filter()
	w:clear "filter_result"
    for e in w:select "render_object_update render_object:in filter_result:new" do
        local ro = e.render_object
        local filterstate = ro.filter_state
		local st = ro.fx.setting.surfacetype

		local filter_result = {}
		for qe in w:select "queue_name:in primitive_filter:in" do
			local qn = qe.queue_name
			local tag = ("%s_%s"):format(qn, st)

			local pf = qe.primitive_filter
			if has_filter_tag(tag, pf) then
				w:sync(tag .. "?in", e)
				local add = ((filterstate & pf.filter_type) ~= 0) and ((filterstate & pf.exclude_type) == 0)
				if add then
					if not e[tag] then
						filter_result[tag] = add
						e[tag] = add
						w:sync(tag .. "?out", e)
					end
				else
					if e[tag] then
						filter_result[tag] = add
						e[tag] = add
						w:sync(tag .. "?out", e)
					end
				end
			end
		end
		e.filter_result = filter_result
    end
end

local function submit_render_objects(viewid, filter, culltag)
	for idx, fn in ipairs(filter) do
		local s = culltag and
			("%s %s:absent render_object:in filter_material?in"):format(fn, culltag[idx]) or
			("%s render_object:in filter_material?in"):format(fn)

		for e in w:select(s) do
			irender.draw(viewid, e.render_object, e.filter_material[fn])
		end
	end
end

function render_sys:render_submit()
	for qe in w:select "visible camera_ref:in render_target:in primitive_filter:in cull_tag?in" do
		local camera = icamera.find_camera(qe.camera_ref)
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
		submit_render_objects(viewid, qe.primitive_filter, qe.cull_tag)
    end
end

local s = ecs.system "end_filter_system"
function s:end_filter()
	w:clear "render_object_update"
end