local fs = require "bee.filesystem"

local function split(s)
    local r = {}
    s:gsub('[^;]*', function (w) r[#r+1] = w end)
    return r
end

local dirs = split(os.getenv "PATH" or "")
local exts = split(os.getenv "PATHEXT" or "")

local function where(name)
    for _, dir in ipairs(dirs) do
        for _, ext in ipairs(exts) do
            if fs.exists(fs.path(dir) / (name..ext)) then
                return true
            end
        end
    end
end

return function ()
    for _, name in ipairs {"pwsh", "powershell"} do
        if where(name) then
            return name
        end
    end
end
