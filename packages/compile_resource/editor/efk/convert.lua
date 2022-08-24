local efkres        = require "efk.resource"
local fileinterface = require "fileinterface"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"

local png_param     = require "editor.texture.png_param"

local stringify     = import_package "ant.serialize".stringify

local tolocalpath
local function preopen(filename)
    return tolocalpath(filename):string()
end

local filefactory = fileinterface.factory { preopen = preopen }
local resctx = efkres.new(filefactory)

local function create_def_texture_file(srcpath)
    local p = png_param.default(srcpath)
    p.gray2rgb = true
    return p
end

local function read_file(p)
    local f<close> = lfs.open(p)
    return f:read "a"
end

local function write_file(p, data)
    local f<close> = lfs.open(p, "wb")
    f:write(data)
end

local function create_texture_file_content(src, localpath)
    local ff = fs.path(src)
    local texfile = ff:replace_extension "texture"
    local texparent = texfile:parent_path()
    local local_texparent = localpath(texparent)
    local local_texfile = local_texparent / texfile:filename()

    if lfs.exist(local_texfile) then
        return read_file(local_texfile)
    end

    return create_def_texture_file(src)
end

return function (input, output, setting, localpath)
    tolocalpath = localpath
    local resources = resctx:list(input)
    for _, fn in ipairs(resources) do
        local c = create_texture_file_content()
        local name = fs.path(fn):filename()
        write_file(output / "textures"/ name, stringify(c))
    end
end