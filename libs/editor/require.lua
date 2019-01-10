local root = "."
local load = load
local io_open = io.open

local function current_path()
    -- TODO 因为macOS的filesystem需要依赖require，所以裸写一个getcwd，等clang支持filesystem后可以简化很多
    local platform = require 'platform'
    local cwd
    if platform.OS == 'OSX' then
        local posixfs = require 'filesystem.posix'
        cwd = posixfs.getcwd()
        if cwd:sub(-1, -1) ~= '/' then
            cwd = cwd .. '/'
        end
    else		
        local cppfs = require 'filesystem.cpp'
        cwd = cppfs.current_path():string()
        if cwd:sub(-1, -1) ~= '/' and cwd:sub(-1, -1) ~= '\\' then
            cwd = cwd .. '/'
        end
    end
    return cwd
end

if root == '.' then
    root = current_path()
end

local function vfs_path(filename)
    if filename:sub(1, 7) == 'engine/' then
        return root .. filename:sub(8)
    end
    return filename
end

local function searchpath(name, path)
    local err = ''
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        local f = io_open(vfs_path(filename), 'r')
        if f then
            return filename, f
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end

local function searcher_Lua(name)
    assert(type(package.path) == "string", "'package.path' must be a string")
    local filename, f = searchpath(name, package.path)
    if not filename then
        return f
    end
	local c = f:read "a"
    local func, err = load(c, "@/vfs/" .. filename)
    f:close()
    if not func then
        error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
    end
    return func, filename
end

package.searchers[2] = searcher_Lua
package.searchpath = searchpath
