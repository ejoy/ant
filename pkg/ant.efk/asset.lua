local efkasset = {}

local lefk       = require "efk"
local ltask      = require "ltask"
local fs         = require "filesystem"
local efk_cb     = require "effekseer.callback"
local textureman = require "textureman.client"
local assetmgr   = import_package "ant.asset"

local function init_fx_files()
    local tasks = {}
    local FxFiles = {}
    for _, name in ipairs{
        "sprite_unlit",
        "sprite_lit",
        "sprite_distortion",
        "sprite_adv_unlit",
        "sprite_adv_lit",
        "sprite_adv_distortion",

        "model_unlit",
        "model_lit",
        "model_distortion",
        "model_adv_unlit",
        "model_adv_lit",
        "model_adv_distortion",
    } do
        tasks[#tasks+1] = {function ()
            local filename = ("/pkg/ant.efk/materials/%s.material"):format(name)
            local r = assetmgr.load_material(filename)
            FxFiles[name] = r.fx
        end}
    end

    for _, t in ltask.parallel(tasks) do
    end
    return FxFiles
end

local FxFiles = init_fx_files()

local function shader_load(materialfile, shadername, stagetype)
    assert(materialfile == nil)
    local fx = FxFiles[shadername] or error (("unknown shader name:%s"):format(shadername))
    return fx[stagetype]
end

local TEXTURES = {}
local TEXTURE_LOAD_QUEUE = {
    pop = function (self)
        local e = self[#self]
        table.remove(self)
        return e
    end,
    empty = function (self)
        return #self == 0
    end,
}

local function texture_load(texname, srgb, id)
    --TODO: need use srgb texture
    assert(texname:match "^/pkg" ~= nil)
	local filename = fs.path(texname):replace_extension "texture":string()
	-- TODO : lazy load filename
	TEXTURES[id] = filename
    TEXTURE_LOAD_QUEUE[#TEXTURE_LOAD_QUEUE+1] = filename
end

local function texture_map(id)
	local filename = assert(TEXTURES[id])
	local tex = TEXTURES[filename]
    if tex then
        if not assetmgr.invalid_texture(tex) then
            TEXTURES[id] = nil
            return tex
        end
    end
end

local function texture_unload(texhandle)
    --TODO
end

local function error_handle(msg)
    print("[EFK ERROR]", debug.traceback(msg))
end

local efk_cb_handle = efk_cb.callback{
    shader_load     = shader_load,
    texture_load    = texture_load,
    texture_unload  = texture_unload,
    texture_map     = texture_map,
	texture_transform = textureman.texture_get_cfunc,
    error           = error_handle,
}

function efkasset.init_efk_ctx(maxcount, viewid, default_texid)
    efk_cb_handle.default = default_texid

    return lefk.startup{
        max_count       = maxcount,
        viewid          = viewid,
        shader_load     = efk_cb.shader_load,
        texture_load    = efk_cb.texture_load,
        texture_get     = efk_cb.texture_get,
        texture_unload  = efk_cb.texture_unload,
		texture_handle  = efk_cb.texture_handle,
        userdata        = {
            callback = efk_cb_handle,
        }
    }
    
end

function efkasset.update_cb_data(background_handle, depth)
    efk_cb_handle.background = background_handle
    efk_cb_handle.depth      = depth
end

function efkasset.check_load_textures()
    while not TEXTURE_LOAD_QUEUE:empty() do
        local tn = TEXTURE_LOAD_QUEUE:pop()
        TEXTURES[tn] = assetmgr.load_texture(tn)
    end
end

return efkasset
