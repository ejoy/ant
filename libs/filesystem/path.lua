local fs = require "filesystem"

local path = {}
path.__index = path


function path.remove_ext(name)
    local path, ext = name:match("(.+)%.([%w_]+)$")
    if ext ~= nil then
        return path
    end

    return name
end

function path.ext(name)
    local ext = name:match(".+%.([%w_]+)$")
    return ext
end

function path.has_parent(pp)
    return pp:match("^[%w_.]+$") == nil
end

function path.filename(name)
    return name:match("[/\\]([%w_.]+)$")    
end

function path.filename_without_ext(name)
    local fn = name:match("[/\\]([%w_]+)%.[%w_]+$")
    return fn
end

function path.parent(fullname)
    local path = fullname:match("(.+)[/\\][%w_.]+$")
    return path
end

function path.join(...)
    local function join_ex(tb, p0, ...)
        if p0 then
            print(p0)
            local lastchar = p0[-1]
            if lastchar == '/' or lastchar == '\\' then
                p0 = p0:sub(1, #p0 - 1)
            end
            table.insert(tb, p0)
            join_ex(tb, ...)
        end
    end

    local tb = {}
    join_ex(tb, ...)
    return table.concat(tb, '/')
end

function path.trim_slash(fullpath)
    return fullpath:match("^%s*[/\\]*(.+)[/\\]")
end

function path.create_dirs(fullpath)    
    fullpath = path.trim_slash(fullpath)
    local cwd = fs.currentdir()
    for m in fullpath:gmatch("[%w_]+") do
        cwd = path.join(cwd, m)
        if not fs.exist(cwd) then
            fs.mkdir(cwd)
        end
    end
end

return path