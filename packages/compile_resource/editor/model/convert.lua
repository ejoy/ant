local export_prefab = require "editor.model.export_prefab"
local export_meshbin = require "editor.model.export_meshbin"
local export_animation = require "editor.model.export_animation"
local export_material = require "editor.model.export_material"
local glbloader = require "editor.model.glTF.glb"
local utility = require "editor.model.utility"

return function (input, output, _, tolocalpath)
    utility.init(input, output)
    local glbdata = glbloader.decode(input)
    local exports = {}
    assert(glbdata.version == 2)
    export_meshbin(output, glbdata, exports)
    export_material(output, glbdata, exports, tolocalpath)
    export_animation(input, output, exports)
    export_prefab(output, glbdata, exports)
    return true, {
        input,
        input .. ".patch"
    }
end
