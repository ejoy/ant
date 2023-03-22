
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
    local cubemap_content = image.pack2cubemap(faces_content)
    local f<close> = lfs.open(fs.path "/pkg/tools.texture/assets":localpath() /"result.ktx", "wb")
    f:write(cubemap_content)
end