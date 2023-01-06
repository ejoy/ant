local function fs_absolute(...)
    local fs = require "filesystem"
    return fs.absolute(...)
end

local function platform_os()
    local platform = require "bee.platform"
    return platform.os
end

local function closeprocess()
    os.exit(true, true)
end

return {
    fs_absolute = fs_absolute,
    platform_os = platform_os,
    closeprocess = closeprocess,
}
