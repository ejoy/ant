local datalist = require 'datalist'

local ARRAY <const> = '--------------------'
local out
local typeinfo

local function prefix(n)
    return ("  "):rep(n)
end

local function pairs_sortk(t)
    local sort = {}
    for k in pairs(t) do
        if type(k) == "string" then
            sort[#sort+1] = k
        end
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

local function pairs_sortv(t)
    local sort = {}
    for _,v in pairs(t) do
        sort[#sort+1] = v
    end
    table.sort(sort)
    return ipairs(sort)
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local PATTERN <const> = "%a%d/%-_."
local PATTERN <const> = "^["..PATTERN.."]["..PATTERN.."]*$"

local function stringify_basetype(name, v)
    if name == 'int' then
        return ('%d'):format(v)
    elseif name == 'real' then
        return convertreal(v)
    elseif name == 'string' then
        if v:match(PATTERN) then
            return v
        else
            return datalist.quote(v)
        end
    elseif name == 'boolean'then
        if v then
            return 'true'
        else
            return 'false'
        end
    elseif name == "tag" then
        return v and 'true' or 'nil'
    elseif name == 'entityid' then
        error('`entityid` is not supported.')
    end
    error('unknown base type:'..name)
end

local function stringify_array_value(c, array, v)
    if c.type ~= 'primtype' then
        return stringify_array_value(typeinfo[c.type], array, v)
    end
    local n = array == 0 and #v or array
    local s = {}
    for i = 1, n do
        s[i] = stringify_basetype(c.name, v[i])
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_map_value(c, v)
    if c.type ~= 'primtype' then
        return stringify_map_value(typeinfo[c.type], v)
    end
    local s = {}
    for k, o in pairs_sortk(v) do
        s[#s+1] = k..':'..stringify_basetype(c.name, o)
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_value(c, v)
    assert(c.type)
    if c.array then
        return stringify_array_value(c, c.array, v)
    end
    if c.map then
        return stringify_map_value(c, v)
    end
    if c.type == 'primtype' then
        return stringify_basetype(c.name, v)
    end
	return stringify_value(typeinfo[c.type], v)
end

local function is_empty_table(t)
    local k = next(t)
    if k then
        return next(t, k) == nil
    end
    return true
end

local stringify_component

local function stringify_component_ref(c, v, n)
    if c.type then
        return stringify_component_ref(typeinfo[c.type], v, n)
    end
    for _, cv in ipairs(c) do
        if v[cv.name] == nil and cv.attrib and cv.attrib.opt then
            goto continue
        end
        if cv.ref then
            if cv.array then
                local vv = v[cv.name]
                out[#out+1] = prefix(n) .. ('%s:'):format(cv.name)
                for i = 1, (cv.array == 0 and #vv or cv.array) do
                    stringify_component(ARRAY, typeinfo[cv.type].name, vv[i], n+1)
                end
                goto continue
            end
            if cv.map then
                local vv = v[cv.name]
                if is_empty_table(vv) then
                    out[#out+1] = prefix(n) .. ('%s: {}'):format(cv.name)
                else
                    out[#out+1] = prefix(n) .. ('%s:'):format(cv.name)
                    for k, o in pairs_sortk(vv) do
                        stringify_component(k..':', typeinfo[cv.type].name, o, n+1)
                    end
                end
                goto continue
            end
            stringify_component(cv.name..':', cv.type, v[cv.name], n)
        else
            out[#out+1] = prefix(n) .. ('%s: %s'):format(cv.name, stringify_value(cv, v[cv.name]))
        end
        ::continue::
    end
end

local function stringify_component_value(name, typename, value, n)
    assert(typeinfo[typename], "unknown type:" .. typename)
    local c = typeinfo[typename]
    if not c.ref then
        out[#out+1] = prefix(n)..('%s %s'):format(name, stringify_value(c, value))
        return
    end
    if type(value) == "table" and next(value) == nil then
        out[#out+1] = prefix(n)..('%s {}'):format(name)
        return
    end
    out[#out+1] = prefix(n)..('%s'):format(name)
    stringify_component_ref(c, value, name == ARRAY and n or (n+1))
end

function stringify_component(name, typename, value, n)
    local ti = typeinfo[typename]
    if ti.multiple then
        for _, vv in ipairs(value) do
            stringify_component_value(name, typename, vv, n)
        end
    else
        stringify_component_value(name, typename, value, n)
    end
end

return function (w, policies, data)
    typeinfo = w._class.component
    out = {}
    out[#out+1] = '---------'
    for _, p in pairs_sortv(policies) do
        out[#out+1] = p
    end
    out[#out+1] = '---------'
    for _, c in ipairs(data) do
        stringify_component(c[1]..':', c[1], c[2], 0)
    end
    out[#out+1] = ''
    return table.concat(out, '\n')
end
