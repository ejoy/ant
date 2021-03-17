local ecs = ...
local world = ecs.world

local declmgr	= require "vertexdecl_mgr"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local iom		= world:interface "ant.objcontroller|obj_motion"

local setting	= import_package "ant.settings".setting
local enable_cluster_shading = setting:data().graphic.lighting.cluster_shading ~= 0

local lt = ecs.transform "light_transform"
function lt.process_entity(e)
	local t = e.light_type
	if (t == "point" or t == "spot") and e.range == nil then
		error(("light:%s need define 'range' attribute"):format(lt))
	elseif t == "spot" and e.radian == nil then
		error("spot light need define 'radian' attribute")
	end

	local range = e.range
	if e.light_type == "directional" then
		if range == 0 then
			range = math.maxinteger
		else
			assert(range > 10000 * 10000, "need very large range for directional light")
		end
	end
	e._light = {
		color		= e.color or {1, 1, 1, 1},
		intensity	= e.intensity or 2,
		range		= range,
		radian		= e.radian,
	}
end

-- light interface
local ilight 	= ecs.interface "light"

function ilight.create(light)
	return world:create_entity {
		policy = {
			"ant.render|light",
			"ant.general|name",
		},
		data = {
			transform	= light.transform,
			name		= light.name or "DEFAULT_LIGHT",
			light_type	= assert(light.light_type),
			color		= light.color or {1, 1, 1, 1},
			intensity	= light.intensity or 2,
			range		= light.range,
			radian		= light.radian,
		}
	}
end

function ilight.data(eid)
	return world[eid]._light
end

function ilight.color(eid)
	return world[eid]._light.color
end

function ilight.set_color(eid, color)
	local l = world[eid]._light
	l.color.v = color

	world:pub{"component_changed", "light", eid}
end

function ilight.intensity(eid)
	return world[eid]._light.intensity
end

function ilight.set_intensity(eid, i)
	world[eid]._light.intensity = i
	world:pub{"component_changed", "light", eid}
end

function ilight.range(eid)
	return world[eid]._light.range
end

function ilight.set_range(eid, r)
	local e = world[eid]
	if e.light_type == "directional" then
		error("directional light do not have 'range' property")
	end

	e._light.range = r
	world:pub{"component_changed", "light", eid}
end

function ilight.radian(eid)
	return world[eid]._light.radian
end

function ilight.set_radian(eid, r)
	local e = world[eid]
	if e.light_type ~= "spot" then
		error(("%s light do not have 'radian' property"):format(e.light_type))
	end

	e._light.radian = r
	world:pub{"component_changed", "light", eid}
end

function ilight.inner_cutoff(eid)
	local l = world[eid]._light
	local r = l.radian
	return r and math.cos(r * 0.5) or 0
end

function ilight.outter_cutoff(eid)
	local l = world[eid]._light
	local r = l.outter_radian
	if r == nil and l.radian then
		r = l.radian * 1.1
	end
	return r and math.cos(r * 0.5) or 0
end

local active_dl
function ilight.directional_light()
	return active_dl
end

function ilight.active_directional_light(eid)
	if eid then
		local e = world[eid]
		assert(e.light_type == "directional")
	end
	active_dl = eid
end

function ilight.max_point_light()
	return 4
end

local lighttypes = {
	directional = 0,
	point = 1,
	spot = 2,
}

function ilight.create_light_buffers()
	local lights = {}
	for _, leid in world:each "light_type" do
		local le = world[leid]
		
		local p	= math3d.tovalue(iom.get_position(leid))
		local d	= math3d.tovalue(math3d.inverse(iom.get_direction(leid)))
		local c = ilight.color(leid)
		local t	= le.light_type
        local enable<const> = 1
        --TODO: use bgfx.memory{('f'):rep(16), }
		lights[#lights+1] = ('f'):rep(16):pack(
			p[1], p[2], p[3], ilight.range(leid) or 10000,
			d[1], d[2], d[3], enable,
			c[1], c[2], c[3], c[4],
			lighttypes[t], ilight.intensity(leid),
			ilight.inner_cutoff(leid),	ilight.outter_cutoff(leid))
	end
    return lights
end

function ilight.use_cluster_shading()
	return enable_cluster_shading
end

local light_buffer
local num_light
function ilight.update_properties(system_properties)
	if ilight.use_cluster_shading() then
		local icluster = world:interface "ant.render|icluster_render"
		icluster.extract_cluster_properties(system_properties)
	else
		system_properties["u_light_count"].v = {num_light, 0, 0, 0}
	end
end

function ilight.update_light_buffers()
	local lb
	local lights = ilight.create_light_buffers()

	if ilight.use_cluster_shading() then
		local icluster = world:interface "ant.render|icluster_render"
		lb = icluster.light_info_buffer_handle()
	else
		if light_buffer == nil then
			light_buffer = bgfx.create_dynamic_vertex_buffer(#lights * 4, declmgr.get "t40".handle, "ra")
		end
		lb = light_buffer
		num_light = #lights
	end

	if lb then
		bgfx.update(lb, 0, bgfx.memory_buffer(table.concat(lights, "")))
	end
end

function ilight.set_light_buffers()
	if ilight.use_cluster_shading() then
		local icluster_render = world:interface "ant.render|icluster_render"
		icluster_render.set_buffers()
	else
		if light_buffer then
			local stage<const> = 12
			bgfx.set_buffer(stage, light_buffer, "r")
		end
	end
end

local mdl = ecs.action "main_directional_light"
function mdl.init(prefab, idx, value)
	local eid = prefab[idx]
	ilight.active_directional_light(eid)
end

local lightsys = ecs.system "light_system"
function lightsys:data_changed()

end