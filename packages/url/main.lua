local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function stringify (t)
    if t == nil then
        return ""
    end
    local s = {}
    for k, v in sortpairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
end


local function create_url(p, t)
    return p .. "?" .. stringify(t)
end

local function parse_utl(url)
    local f, s = url:match "^([^?]*)%??(.*)$"
    local setting = {}
    if s then
        s:gsub("([^=&]*)=([^=&]*)", function(k ,v)
            setting[k] = v
        end)
    end
    return f, setting, s
end

return {
    create = create_url,
    parse = parse_utl,
}