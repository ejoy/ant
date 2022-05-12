local ecs	= ...
local world = ecs.world
local w		= world.w

local assetmgr		= require "asset"
local sa			= require "system_attribs"

local imaterial = ecs.interface "imaterial"

function imaterial.set_property(e, who, what)
	e.render_object.material[who] = what
end

function imaterial.get_property(e, who)
	return e.render_object.material[who]
end

local function stringify_setting(s)
	if s == nil then
		return ""
	end
	local kk = {}
	for k in pairs(s) do
		kk[#kk+1] = k
	end
	table.sort(kk)
	local ss = {}
	for _, k in ipairs(kk) do
		local v = s[k]
		ss[#ss+1] = k.."="..v
	end
	return table.concat(ss, "&")
end

function imaterial.create_url(mp, s)
	return mp .. "?" .. stringify_setting(s)
end

function imaterial.load(mp, setting)
	return assetmgr.resource(imaterial.create_url(mp, setting))
end

function imaterial.load_url(url)
	return assetmgr.resource(url)
end

function imaterial.system_attribs()
	return sa
end

local ms = ecs.system "material_system"

function ms:component_init()
	w:clear "material_result"
	for e in w:select "INIT material:in material_setting?in material_result:new" do
		e.material_result = imaterial.load(e.material, e.material_setting)
	end
end