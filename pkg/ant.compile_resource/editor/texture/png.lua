local convert_image = require "editor.texture.util"
local pngparam = require "editor.texture.png_param"
local depends  = require "editor.depends"

return function(input, output)
    local p = pngparam.default(input)
    local ok, err = convert_image(output, p)
    if not ok then
        return ok, err
    end
    local deps = {}
    depends.add(deps, input)
    return true, deps
end
