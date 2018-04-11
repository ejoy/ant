local util = {}
util.__index = util

function util.write_to_file(fn, content)
    local f = io.open(fn, "w")
    f:write(content)
    f:close()
end


return util