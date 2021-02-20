local ecs = ...
local world = ecs.world

local assetmgr		= require "asset"
local ext_material	= require "ext_material"

local mpt = ecs.transform "material_prefab_transform"
local function load_material(m, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end
	return {
		fx = fx,
		properties = properties,
		state = m.state
	}
end

function mpt.process_prefab(e)
	local m = e.material
	if m then
		local c = e._cache_prefab
		local m = load_material(m, c.material_setting)
		c.fx, c.properties, c.state = m.fx, m.properties, m.state
	end
end

local mst = ecs.transform "material_setting_transform"
function mst.process_prefab(e)
	e._cache_prefab.material_setting = {}
end

local imaterial = ecs.interface "imaterial"
function imaterial.load(materialpath, setting)
	local m = world.component "material"(materialpath)
	return load_material(m, setting)
end

local math3d = require "math3d"
local bgfx = require "bgfx"

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
	if p.type == "s" then
		if type(what) ~= "table" then
			error(("texture property must resource data:%s"):fromat(who))
		end

		if p.ref then
			p.ref = nil
		end
		p.value = what
		p.set = set_texture
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

function imaterial.set_property(eid, who, what)
	if world:interface "ant.render|system_properties".get(who) then
		error(("global property could not been set:%s"):format(who))
	end

	local rc = world[eid]._rendercache
	imaterial.set_property_directly(rc.properties, who, what)
end

function imaterial.get_property(eid, who)
	local rc = world[eid]._rendercache
	return rc.properties and rc.properties[who] or nil
end

function imaterial.has_property(eid, who)
	local rc = world[eid]._rendercache
	return rc.properties and rc.properties[who] ~= nil
end

local function which_type(u)
	local t = type(u)
	if t == "table" then
		return u.stage and "s" or "array"
	end

	assert(t == "userdata")
	return "v"
end

function imaterial.which_set_func(u)
	local t = which_type(u)
	if t == "s" then
		return set_texture
	end

	return t == "array" and set_uniform_array or set_uniform
end


local m = ecs.component "material"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(self)
	end
	return ext_material.init(self)
end

local mt = ecs.transform "material_transform"

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

local lightbuffer_property

local function generate_properties(fx, properties)
	if fx == nil then
		return nil
	end

	local uniforms = fx.uniforms
	local isp 		= world:interface "ant.render|system_properties"
	local new_properties
	properties = properties or {}
	if uniforms and #uniforms > 0 then
		new_properties = {}
		for _, u in ipairs(uniforms) do
			local n = u.name
			local v = to_v(properties[n]) or isp.get(n)
			new_properties[n] = {
				value = v,
				handle = u.handle,
				type = u.type,
				set = imaterial.which_set_func(v),
				ref = true,
			}
		end
	end

	--TODO: right now, bgfx shaderc tool would not save buffer binding to uniforom info after shader compiled(currentlly only sampler/const buffer will save in uniform infos), just work around it right now

	local setting = fx.setting
	if setting.lighting == "on" then
		if lightbuffer_property == nil then
			lightbuffer_property = {
				type = "b",
				set = function ()
					local ilight = world:interface "ant.render|light"
					ilight.set_light_buffers()
				end,
				ref = true,
			}
		end
		new_properties = new_properties or {}
		new_properties.light_properties = lightbuffer_property
	end
	return new_properties
end

function mt.process_entity(e)
	local rc = e._rendercache
	local c = e._cache_prefab

	rc.fx 			= c.fx
	rc.properties 	= generate_properties(c.fx, c.properties)
	rc.state 		= c.state
end