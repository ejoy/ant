local fs = require "filesystem.local"
--local fs = require "bee.filesystem"

local function copy_directory(from, to, filter)
    fs.create_directories(to)
    for fromfile in from:list_directory() do
        if (not filter) or filter(fromfile) then
            if fs.is_directory(fromfile) then
                copy_directory(fromfile, to / fromfile:filename(), filter)
            else
                fs.copy_file(fromfile, to / fromfile:filename(), true)
            end
        end
    end
end

local input = fs.path "./"
local output = fs.path "../install"

fs.remove_all(output)

copy_directory(input / "bin" / "msvc" / "Debug", output, function (path)
    return path:equal_extension '.dll' or path:equal_extension'.exe'
end)
copy_directory(input / "engine", output / "engine")
copy_directory(input / "packages", output / "packages")
copy_directory(input / "tools" / "prefab_editor", output / "tools" / "prefab_editor", function (path)
    return path == input / "tools" / "prefab_editor" / ".build"
end)
