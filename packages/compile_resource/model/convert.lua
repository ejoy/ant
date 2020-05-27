local export_prefab = require "model.export_prefab"
local export_meshbin = require "model.export_meshbin"
local export_animation = require "model.export_animation"
local export_pbrm = require "model.export_pbrm"
local glbloader    = import_package "ant.glTF".glb

return function (_, input, output)
    local glbdata = glbloader.decode(input:string())
    local meshscene = export_meshbin(output, glbdata)
    local materialfiles = export_pbrm(output, glbdata)
    export_animation(input, output)
    export_prefab(output, meshscene, materialfiles)
    return true, ""
end
