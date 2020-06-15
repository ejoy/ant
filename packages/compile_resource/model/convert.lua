local export_prefab = require "model.export_prefab"
local export_meshbin = require "model.export_meshbin"
local export_animation = require "model.export_animation"
local export_material = require "model.export_material"
local glbloader = require "model.glTF.glb"

return function (input, output)
    local glbdata = glbloader.decode(input)
    local exports = {}
    assert(glbdata.version == 2)
    export_meshbin(output, glbdata, exports)
    export_material(output, glbdata, exports)
    export_animation(input, output, exports)
    export_prefab(output, glbdata, exports)
    return true
end
