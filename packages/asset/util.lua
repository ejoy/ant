local util = {}

local fs = require "filesystem"

function util.parse_embed_file(filepath)
    local f = fs.open(filepath, "rb")
    if f == nil then
        error(string.format("could not open file:%s", filepath:string()))
        return 
    end
    local magic = f:read(4)
    if magic ~= "res\0" then
        error(string.format("wrong format from file:%s",filepath:string()))
        return
    end

    local function read_pairs()
        local mark, len = f:read(4), f:read(4)
        return mark, string.unpack("<I4", len)
    end

    local luamark, lualen = read_pairs()
    assert(luamark == "lua\0")
    
    local luacontent = f:read(lualen)
    local luattable = {}
    local r, err = load(luacontent, "asset lua content", "t", luattable)
    if r == nil then
        log.error(string.format("parse file failed:%s, error:%s", filepath:string(), err))
        return nil
    end
    r()
    ----------------------------------------------------------------
    local binmark, binlen = read_pairs()
    assert(binmark == "bin\0")
    
    local binary = f:read(binlen)
    f:close()
    return luattable, binary
end

return util
