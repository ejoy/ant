local function fs_absolute(...)
    local fs = require "filesystem"
    return fs.absolute(...)
end

local function platform_os()
    local platform = require "platform"
    return platform.OS
end

return {
    fs_absolute = fs_absolute,
    platform_os = platform_os
}
