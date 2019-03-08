local vfs = require "vfs"

local function join(dir, file)
    if file:sub(1, 1) == '/' then
        return file
    end
    return dir:gsub("(.-)/?$", "%1") .. '/' .. file
end

local function each(dir)
    local list = vfs.list(dir)
    local name
    return function()
        name = next(list, name)
        if not name then
            return
        end
        return name
    end
end


return {
    join = join,
    each = each,
    type = vfs.type,
    realpath = vfs.realpath,
}
 