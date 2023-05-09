
local platform = require "bee.platform"
local fs = require "bee.filesystem"

local function find_adb()
    if platform.os == "windows" then
        local LocalAppData = os.getenv "LocalAppData"
        if LocalAppData then
            local path = LocalAppData:gsub("\\", "/") .. "/Android/Sdk/platform-tools/adb.exe"
            if fs.exists(path) then
                return path
            end
        end
    end
    return ""
end

return find_adb()
