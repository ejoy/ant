local glb = require "model.glTF.glb"
local gltf = require "model.glTF.gltf"

local function decode(filename, fetch)
    if filename:match "%.glb$" then
        return glb.decode(filename)
    else
        return gltf.decode(filename, fetch)
    end
end

return {
    decode = decode,
}