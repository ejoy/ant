local convert_image = require "editor.texture.util"
local pngparam = require "editor.texture.png_param"

return function(input, output, setting)
    local p = pngparam.default(input)
    p.setting = setting

    local ok, err = convert_image(output, p)
    if not ok then
        return ok, err
    end
    return true, { input }
end
