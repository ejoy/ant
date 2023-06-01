return {
    fileserver = function ()
        local m = require "main"
        return {
            init_setting = m.init_setting,
            set_setting  = m.set_setting,
            compile_file = m.compile_file,
        }
    end,
    sampler = require "editor.texture.sampler",
}
