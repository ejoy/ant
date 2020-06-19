local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local bgfx = require "bgfx"
local mt = ecs.transform "material_transform"
local fs_local = import_package "ant.utility".fs_local
local fs = require "filesystem"
local function load_state(filename)
	return type(filename) == "string" and fs_local.datalist(fs.path(filename):localpath()) or filename
end

local function load_material(m, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end

	return {
		fx = fx,
		properties = properties,
		state = bgfx.make_state(load_state(m.state))
	}
end

function mt.process_prefab(e)
	local m = e.material
	if m then
		local c = e._cache
		local m = load_material(m, c.material_setting)
		c.fx, c.properties, c.state = m.fx, m.properties, m.state
	end
end

local im_class = ecs.interface "imaterial"
function im_class.load(materialpath, setting)
	local m = world.component "resource"(materialpath)
	return load_material(m, setting)
end

local math3d = require "math3d"
local bgfx = require "bgfx"
local function set_uniform(src, dst)
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
		else
			src.id = t2mid(dst)
		end
	else
		src.id = dst
	end
end

function im_class.set_property(eid, who, what)
	if world:interface "ant.render|render_properties".get(who) then
		error(("global property could not been set:%s"):format(who))
	end

	local rc = world[eid]._rendercache
	local p = rc.properties[who]
	if p == nil then
		log.warn(("entity:%s, do not have property:%s"):format(world[eid].name or tostring(eid), who))
		return
	end
	if p.u.type == "s" then
		if type(what) ~= "number" then
			error(("texture property should pass texture handle%s"):fromat(who))
		end

		if p.ref then
			p.ref = nil
			local v = p.value
			p.value = {
				stage = v.stage,
				texture = {},
			}
		end
		p.value.texture.handle = what
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

		set_uniform(p.value, what)
	end
end

function im_class.submit(p)
	p.u:set(p.value)
end