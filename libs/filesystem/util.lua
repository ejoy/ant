local util = {}
util.__index = util

function util.write_to_file(fn, content)
    local f = io.open(fn, "w")
    f:write(content)
    f:close()
end

function util.read_from_file(filename)
    local f = io.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

return util