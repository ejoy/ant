local util = {}; util.__index = util

local shader_mgr = require "shader_mgr"
local assetmgr = require "asset"
local fs = require "filesystem"

function util.create_shader_program_from_file(fxpath)
    local fxloader = require "ext_fx".loader
    return fxloader(fxpath)
end

local function mnext(tbl, index)
    if tbl then
        local k, v
        while true do
            k, v = next(tbl, index)
            local tt = type(k)
            if tt == "string" or tt == "nil" then
                break
            end
            index = k
        end

        return k, v
    end
end

function util.mpairs(t)
    return mnext, t, nil
end

function util.each_texture(properties)
    if properties then
        local textures = properties.textures
        if textures then
            return util.mpairs(textures)
        end
    end
    return mnext, nil, nil
end

function util.load_material_textures(properties)
    for _, tex in util.each_texture(properties) do
        assetmgr.load(tex.ref_path)
    end

	return properties
end

function util.unload_material_textures(properties)
    for _, tex in util.each_texture(properties) do
        assetmgr.unload(tex.ref_path)
    end
end

function util.load_material_properties(properties)
    return util.load_material_textures(properties)
end

function util.unload_material_properties(properties)
    util.unload_material_textures(properties)
end

function util.parse_embed_file(filepath)
    local f = fs.open(filepath, "rb")
    if f == nil then
        error(string.format("could not open file:%s", filepath:string()))
        return 
    end
    local magic = f:read(4)
    if magic ~= "res\0" then
        error(string.format("wrong format from file:%s",filepath:string()))
        return 
    end

    local function read_pairs()
        local mark, len = f:read(4), f:read(4)
        return mark, string.unpack("<I4", len)
    end

    local luamark, lualen = read_pairs()
    assert(luamark == "lua\0")
    
    local luacontent = f:read(lualen)
    local luattable = {}
    local r, err = load(luacontent, "asset lua content", "t", luattable)
    if r == nil then
        log.error(string.format("parse file failed:%s, error:%s", filepath:string(), err))
        return nil
    end
    r()
    ----------------------------------------------------------------
    local binmark, binlen = read_pairs()
    assert(binmark == "bin\0")
    
    local binary = f:read(binlen)
    f:close()
    return luattable, binary

end

function util.def_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"translucent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "on",			-- "on"/"off"
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
end

function util.load_surface_type(surfacetype)
	if surfacetype == nil then
		return util.def_surface_type()
	end

	for k, v in pairs(util.def_surface_type()) do
		if surfacetype[k] == nil then
			surfacetype[k] = v
		end
	end
	return surfacetype
end

return util