local lfs = require "filesystem.local"
local cm = require "compile"
local config = require "config"

if not __ANT_RUNTIME__ then
    require "editor.compile"
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

return {
    init        = config.init,
    read_file   = read_file,
    compile     = cm.compile,
    compile_path= cm.compile_path,
    compile_dir = cm.compile_dir,
}
