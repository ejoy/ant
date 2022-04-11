local ecs = ...
local world = ecs.world
local w = world.w

local math3d		= require "math3d"
local bgfx			= require "bgfx"

local assetmgr		= require "asset"
local ext_material	= require "ext_material"

local function load_material(m, c, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end
	c.fx			= fx
	c.properties	= properties
	c.state			= m.state
	c.stencil		= m.stencil
	return c
end

local imaterial = ecs.interface "imaterial"

local function set_uniform(p)
	return bgfx.set_uniform(p.handle, p.value)
end

local function set_uniform_array(p)
	return bgfx.set_uniform(p.handle, table.unpack(p.value))
end

local function set_texture(p)
	local v = p.value
	return bgfx.set_texture(v.stage, p.handle, v.texture.handle, v.texture.flags)
end

local function set_buffer(p)
	local v = p.value
	return bgfx.set_buffer(v.stage, v.handle, v.access)
end

local function set_image(p)
    local v = p.value
    bgfx.set_image(v.stage, v.image.handle, v.mip, v.access)
end

local function update_uniform(p, dst)
	local src = p.value
	if type(dst) == "table" then
		local t = type(dst[1])
		local function t2mid(v)
			return #v == 4 and math3d.vector(v) or math3d.matrix(v)
		end
		if t == "table" or t == "userdata" then
			if #src ~= #dst then
				error(("invalid uniform data, #src:%d ~= #dst:%d"):format(#src, #dst))
			end
			local to_v = t == "table" and t2mid or function(dv) return dv end

			for i=1, #src do
				src[i].id = to_v(dst[i])
			end
			p.set = set_uniform_array
		else
			src.id = t2mid(dst)
			p.set = set_uniform
		end
	else
		src.id = dst
		p.set = set_uniform
	end
end

function imaterial.set_property_directly(properties, who, what)
	local p = properties[who]
	if p == nil then
		log.warn(("entity do not have property:%s"):format(who))
		return
	end

	local t = p.type
	if t == "s" or t == "i" then
		if type(what) ~= "table" then
			error(("texture property must resource data:%s"):format(who))
		end

		if p.ref then
			p.ref = nil
		end
		p.value = what
	else
		--must be uniform: vector or matrix
		if p.ref then
			p.ref = nil
			local v = p.value
			if type(v) == "table" then
				p.value = {}
				for i=1, #v do
					p.value[i] = math3d.ref(v[i])
				end
			else
				p.value = math3d.ref(v)
			end
		end

		update_uniform(p, what)
	end
end


function imaterial.set_property(e, who, what)
	if ecs.import.interface "ant.render|isystem_properties".get(who) then
		error(("global property could not been set:%s"):format(who))
	end
	local ro = e.render_object
	if ro then
		imaterial.set_property_directly(ro.properties, who, what)
	end
end

function imaterial.get_property(e, who)
	local ro = e.render_object
	return ro.properties and ro.properties[who] or nil
end

function imaterial.has_property(e, who)
	return imaterial.get_property(e, who) ~= nil
end

function imaterial.get_setting(e)
	local ro = e.render_object
	return ro.fx.setting
end

local function which_type(u)
	local t = type(u)
	if t == "table" then
		if u.access then
			return u.image and "i" or "b"
		end
		return u.stage and "s" or "array"
	end

	assert(t == "userdata")
	return "u"
end

local set_funcs<const> = {
	s		= set_texture,
	i		= set_image,
	b		= set_buffer,
	array	= set_uniform_array,
	u		= set_uniform,
}

local function which_set_func(u)
	local t = which_type(u)
	return set_funcs[t]
end

function imaterial.property_set_func(t)
	return set_funcs[t]
end

local function init_material(mm)
	if type(mm) == "string" then
		return assetmgr.resource(mm)
	end
	return ext_material.init(mm)
end

local function to_v(t)
	if t == nil then
		return
	end
	assert(type(t) == "table")
	if t.stage then
		return t
	end
	if type(t[1]) == "number" then
		return #t == 4 and math3d.ref(math3d.vector(t)) or math3d.ref(math3d.matrix(t))
	end
	local res = {}
	for i, v in ipairs(t) do
		if type(v) == "table" then
			res[i] = #v == 4 and math3d.ref(math3d.vector(v)) or math3d.ref(math3d.matrix(v))
		else
			res[i] = v
		end
	end
	return res
end


local function generate_properties(fx, properties)
	if fx == nil then
		return nil
	end

	local uniforms = fx.uniforms
	local isp 		= ecs.import.interface "ant.render|isystem_properties"
	local new_properties
	properties = properties or {}
	if uniforms and #uniforms > 0 then
		new_properties = {}
		for _, u in ipairs(uniforms) do
			local n = u.name
			if not n:match "@data" then
				local v
				if "s_lightmap" == n then
					v = {stage = 8, texture={}}
				else
					v = to_v(properties[n]) or isp.get(n)
					if v == nil then
						error(("not found property:%s"):format(n))
					end
				end

				new_properties[n] = {
					value	= v,
					handle	= u.handle,
					type	= which_type(v),
					set		= which_set_func(v),
					ref		= true,
				}
			end
		end
	end

	--TODO: right now, bgfx shaderc tool would not save buffer binding to uniforom info after shader compiled(currentlly only sampler/const buffer will save in uniform infos), just work around it right now

	local setting = fx.setting
	if setting.lighting == "on" then
		new_properties = new_properties or {}
		local ilight = ecs.import.interface "ant.render|ilight"

		local buffer_names = {"b_light_info"}
		if ilight.use_cluster_shading() then
			buffer_names[#buffer_names+1] = "b_light_grids"
			buffer_names[#buffer_names+1] = "b_light_index_lists"
		end

		for _, n in ipairs(buffer_names) do
			local v = isp.get(n)
			new_properties[n] = {
				value	= v,
				set		= imaterial.property_set_func "b",
				type 	= "b",
				ref		= true,
			}
		end
	end
	return new_properties
end

local function build_material(m, ro)
	ro.fx 			= m.fx
	ro.properties 	= generate_properties(m.fx, m.properties)
	ro.state 		= m.state
	ro.stencil		= m.stencil
end

function imaterial.load(mp, setting)
	local mm = assetmgr.resource(mp)

	local mr = {}
	build_material(load_material(mm, {}, setting), mr)
	return mr
end

local ms = ecs.system "material_system"
function ms:component_init()
	w:clear "material_result"
    for e in w:select "INIT material:in material_setting?in material_result:new" do
		local mm = load_material(init_material(e.material), {}, e.material_setting)
		e.material_result = {}
		build_material(mm, e.material_result)
	end
end

-- material animation
local ima = ecs.interface "imaterial_animation"
function ima.create(name, property, frames)
    return ecs.create_entity{
        policy = {
            "ant.asset|material_animation",
            "ant.general|name",
        },
        data = {
            material_animation = {
				property = property,
				frames = frames or {},
				play_state = {}
            },
            name = name or "noname"
        }
    }
end

function ima.add(e, time_ms, value, idx)
    local frames = e.material_animation.frames
	idx = idx or #frames+1
	table.insert(frames, idx, {
        value	 	= value,
        time 		= time_ms,	--ms
    })
end

function ima.remove(e, idx)
    idx = idx or #e.material_animation.frames
    table.remove(e.material_animation.frames, idx)
end

function ima.clear(e)
    e.material_animation.frames = {}
end

function ima.stop(e)
	local ps = e.material_animation.play_state
    if ps.target_e then
		imaterial.set_property(world:entity(ps.target_e), e.material_animation.property, ps.restore_value)
		ps.target_e = nil
		ps.playing = false
	end
end

function ima.play(e, target, loop)
	if not world:entity(target).render_object then
		return
	end
	ima.stop(e)
	local pro = imaterial.get_property(world:entity(target), e.material_animation.property)
	if not pro then
		return
	end
	local ps = e.material_animation.play_state
	ps.target_e = target
	ps.loop = loop
	ps.current_time = 0
	ps.playing = true
	ps.restore_value = (type(pro.value) == "userdata") and math3d.totable(pro.value) or pro.value
end

local ma_sys = ecs.system "material_animation_system"
function ma_sys:component_init()
    -- for e in w:select "INIT material_animation:in" do
    --     e.material_animation.play_state = {
    --         current_time = 0,
    --         target_e = nil,
	-- 		loop = false,
	-- 		playing = false
    --     }
    -- end
end

local timer = ecs.import.interface "ant.timer|itimer"

local function step_material_anim(mat_anim, delta_time)
	local frames = mat_anim.frames
	if #frames < 2 then return end

	local play_state = mat_anim.play_state
	local lerp = function (v0, v1, f)
		if type(v0) == "table" then
			local count = #v0
			local ret = {}
			for i = 1, count do
				ret[#ret + 1] = v0[i] + (v1[i] - v0[i]) * f
			end
			return ret
		else
			return v0 + (v1 - v0) * f
		end
	end
	local function get_value(time)
		local frame_count = #frames
		for i = 1, frame_count do
			if time < frames[i].time then
				local factor = math.min((time - frames[i-1].time) / (frames[i].time - frames[i-1].time), 1.0)
				return lerp(frames[i-1].value, frames[i].value, factor), false
			elseif i == frame_count then
				return frames[i].value, true
			end
		end
	end

	local value, last = get_value(play_state.current_time)
	imaterial.set_property(world:entity(play_state.target_e), mat_anim.property, value)
	play_state.current_time = play_state.current_time + delta_time
	if last then
		if play_state.loop then
			play_state.current_time = 0
		else
			play_state.playing = false
			imaterial.set_property(world:entity(play_state.target_e), mat_anim.property, play_state.restore_value)
			play_state.target_e = nil
		end
	end
end

function ma_sys.data_changed()
	local delta_time = timer.delta()
	for e in w:select "material_animation:in" do
		local ma = e.material_animation
		if ma.play_state.playing then
			step_material_anim(ma, delta_time)
		end
	end
end