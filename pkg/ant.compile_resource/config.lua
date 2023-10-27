local lfs = require "bee.filesystem"
local sha1 = require "sha1"
local serialize = import_package "ant.serialize"
local vfs = require "vfs"

local function writefile(filename, data)
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local function init(setting)
    local setting_str = serialize.stringify(setting)
    local hash = sha1(setting_str):sub(1,7)
    local binpath = lfs.path(vfs.repopath()) / ".build" / (setting.os.."_"..hash)
    lfs.create_directories(binpath)
    writefile(binpath / ".setting", setting_str)
    for _, ext in ipairs {"glb", "texture", "material"} do
        lfs.create_directory(binpath / ext)
    end
    return {
        binpath = binpath,
        setting = setting,
    }
end

return {
    init = init,
}
