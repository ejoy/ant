return {
    fileserver = function ()
        if __ANT_RUNTIME__ then
            return
        end
        local editor = require "editor.compile"
        local config = require "editor.config"
        return {
            init_setting = config.init,
            set_setting  = config.set,
            compile_file = editor.compile_file,
        }
    end,
    sampler = require "editor.texture.sampler",
}
