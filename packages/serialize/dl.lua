local datalist = require "datalist"
local patch = require "patch"
local fs = require "filesystem"
local parse

local function readfile(filename)
	local f = assert(fs.open(fs.path(filename), "r"))
	local data = f:read "a"
	f:close()
	return data
end

local function apply_patch(t)
    assert(type(t[1]) == "table" and type(t[1][1]) == "string")
    local source = parse(readfile(t[1][1]))
    local ok, res = patch.apply(source, t, 2)
    if not ok then
        error "The patch was not applied."
    end
    return res
end

function parse(content)
    local t = datalist.parse(content)
    if not t[1] then
        return t
    end
    return apply_patch(t)
end

return parse
