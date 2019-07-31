package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"

package.path = table.concat(
    {
        "./?.lua",
        "./packages/fileconvert/texture/?.lua",
        "./packages/fileconvert/?.lua",
        "./packages/utility/?.lua",
        "./engine/?.lua",        
    }, ";")

local fs = require "filesystem.local"
local util = require "util"
local ddsutil =require "dds_util"
local vaild_textures_extensions = {
    ".dds", ".png", ".bmp", ".exr", ".tga",
}

local fs_util = require "fs_util"
local assetpath = fs.path "test/samples/unity_viking/Assets"
local files = fs_util.list_files(assetpath, table.concat(vaild_textures_extensions, '|'), {})

local function file_format_info(filepath)
    local ext = filepath:extension():string():lower()
    if ext == ".png" or ext == ".bmp" then
        return {format = "RGBA", colorspace = "linear", compressed = false}
    end

    if ext == ".exr" then
        return {format = "RGBA", colorspace = "HDR", compressed = false}
    end

    if ext == ".dds" then
        return ddsutil.dds_format(filepath)
    end

    error(string.format("not support type:%s", ext))
end

local stringify = require "stringify"

local function is_normal_map(filepath)
    local filename = filepath:filename():string():lower()
    if filename:match "_n%.dds$" then
        return true
    end
end

for i=1, #files do
    local f = files[i]
    local lk = util.rawtable(fs.path "packages/fileconvert/texture/default.texture.lk")

    local info = file_format_info(f)
    
    lk.colorspace = info.colorspace
    lk.normalmap = is_normal_map(f)
    if info.compressed then
        local astcfmt = info.format == "BC1" and "ASTC6x6" or "ASTC4x4"
        lk.compress = {
            window  = info.format,
            ios     = astcfmt,
            android = astcfmt,
        }
    else
        lk.format = info.format
    end

    local lkfilename = fs.path(f:string() .. ".lk")

    local r = stringify(lk, true, true)
	local glblk = fs.open(lkfilename, "w")
	glblk:write(r)
    glblk:close()
end

