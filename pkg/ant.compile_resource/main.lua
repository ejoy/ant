return {
    fileserver = function ()
        if __ANT_RUNTIME__ then
            return
        end
        return require "editor.compile"
    end,
    sampler = require "editor.texture.sampler",
}
