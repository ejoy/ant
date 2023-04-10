
local lfs = require "filesystem.local"
local fs = require "filesystem"
local image = require "image"

local facefiles = {
    fs.path "/pkg/tools.texture/assets/simple_cubemap/right-green.png",
    fs.path "/pkg/tools.texture/assets/simple_cubemap/left-yellow.png",
    fs.path "/pkg/tools.texture/assets/simple_cubemap/top-white.png",
    fs.path "/pkg/tools.texture/assets/simple_cubemap/bottom-black.png",
    fs.path "/pkg/tools.texture/assets/simple_cubemap/forward-blue.png",
    fs.path "/pkg/tools.texture/assets/simple_cubemap/backward-red.png",
}

local faces_content = {}

for idx, f in ipairs(facefiles) do
    local ff<close> = fs.open(f, "rb")
    faces_content[idx] = ff:read "a"
end

do
    local ext = "KTX"
    local cubemap_content = image.pack2cubemap(faces_content, false, ext)

    local filename = "result." .. ext
    local function write_file(p, c)
        local f<close> = lfs.open(p, "wb")
        f:write(c)
    end

    local dir = fs.path "/pkg/tools.texture/assets":localpath()

    write_file(dir /filename, cubemap_content)

    local equirectangular = image.cubemap2equirectangular(cubemap_content)
    write_file(dir / "tt.hdr", equirectangular)

    local cm2 = image.equirectangular2cubemap(equirectangular)
    write_file(dir / "cm.ktx", cm2)
end