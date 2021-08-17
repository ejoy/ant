local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local isp		= world:interface "ant.render|isystem_properties"
local irender	= world:interface "ant.render|irender"
local ies		= world:interface "ant.scene|ientity_state"
local icamera	= world:interface "ant.camera|camera"
local render_sys = ecs.system "render_system"

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
		pf.filter_type = ies.create_state(pf.filter_type)
		pf._DEBUG_excule_type = pf.excule_type
		pf.excule_type = pf.excule_type and ies.create_state(pf.excule_type) or 0
	end
end

function render_sys:entity_done()
	for e in w:select "material_result:in render_object:in" do
		local ro = e.render_object
		local mr = e.material_result
		ro.fx			= mr.fx
		ro.properties	= mr.properties
		ro.state		= mr.state
		ro.stencil		= mr.stencil
	end
end

function render_sys:update_system_properties()
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
    for e in w:select "render_object_update render_object:in filter_result:temp" do
        local ro = e.render_object
        local state = ro.entity_state
		local st = ro.fx.setting.surfacetype

		local filter_result = {}
		for qe in w:select "queue_name:in primitive_filter:in" do
			local qn = qe.queue_name
			local tag = ("%s_%s"):format(qn, st)

			local pf = qe.primitive_filter
			if has_filter_tag(tag, pf) then
				local synctag = tag .. "?out"
				local add = ((state & pf.filter_type) ~= 0) and ((state & pf.excule_type) == 0)
				e[tag] = add
				if add then
					filter_result[tag] = true
				end
				w:sync(synctag, e)
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
		--TODO: should keep camera always vaild
        local camera = icamera.find_camera(qe.camera_ref)
		if camera then
			local rt = qe.render_target
			local viewid = rt.viewid

			bgfx.touch(viewid)
			bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
			submit_render_objects(viewid, qe.primitive_filter, qe.cull_tag)
		end
    end
end

local s = ecs.system "end_filter_system"
function s:end_filter()
	w:clear "render_object_update"
end