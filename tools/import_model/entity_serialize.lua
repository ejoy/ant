local util = {}; util.__index = util

local TRANSFORM = [[
transform: $transform
  srt: $srt

]]

local IDENTITY_TRANSFORM = [[
      s: {1, 1, 1, 0}
      r: {0, 0, 0, 1}
      t: {0, 0, 0, 1}
]]

local tab<const> = "  "
local tab_cache = {}
local function get_tab(depth)
    local c = tab_cache[depth]
    if c then
        return c
    end

    local newtab = ""
    for i=1, depth do
        newtab = newtab .. tab
    end

    tab_cache[depth] = newtab
    return newtab
end

local function add_line(c, tab)
    local t = c .. "\n"
    if tab then
        return tab .. t
    end
    return t
end

local function stringify_vector(name, v, lastv)
    lastv = lastv or 0
    local fmt = name .. ":" .. "{%d, %d, %d, %d}"
    if #v == 1 then
        return fmt:format(v, v, v, lastv)
    end

    if #v == 3 then
        return fmt:format(v[1], v[2], v[3], lastv)
    end

    if #v == 4 then
        return fmt:format(v[1], v[2], v[3], v[4])
    end
end

function util.transform(srt, roottab)
    local srt_tab = roottab .. get_tab(2)

    local srt_last_v = {
        s = 0, t = 1
    }
    
    local ss = {}
    for _, n in ipairs{"s", "r", "t"} do
        if srt[n] then
            ss[#ss+1] = add_line(stringify_vector(n, srt[n], srt_last_v[n]), srt_tab)
        end
    end

    if #ss == 0 then
        return TRANSFORM .. IDENTITY_TRANSFORM
    end

    return TRANSFORM .. table.concat(ss, "\n")
end

function util.resource()

end

return util
