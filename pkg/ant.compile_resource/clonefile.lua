local lfs = require "bee.filesystem"
local platform = require "bee.platform"

if platform.os == "windows" then
    local support_symlink = pcall(lfs.create_symlink, ".test.symlink", ".test.symlink")
    lfs.remove_all ".test.symlink"
    if support_symlink then
        return function (a, b)
            lfs.create_symlink(a, b)
        end
    else
        return function (a, b)
            lfs.copy_file(a, b, lfs.copy_options.overwrite_existing)
        end
    end
end

if platform.os == "macos" then
    --TODO:
    -- Packaged ios ipa cannot contain symbolic links.
    -- Maybe use clonefile to improve speed.
    return function (a, b)
        lfs.copy_file(a, b, lfs.copy_options.overwrite_existing)
    end
end

return function (a, b)
    lfs.create_symlink(a, b)
end
