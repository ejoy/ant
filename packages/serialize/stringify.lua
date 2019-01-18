local stringify_value

local function stringify_simple_array(out, n, value)
    local str = {}
    for _, v in ipairs(value) do
        assert(type(v) ~= 'table')
        stringify_value(str, n, v)
    end
    out[#out+1] = ('[%s]'):format(table.concat(str, ','))
end

local function stringify_array(out, n, value)
    out[#out+1] = '['
    for _, v in ipairs(value) do
        local str = {}
        stringify_value(str, n, v)
        if #str > 1 then
            table.move(str, 1, #str, #out+1, out)
        else
            out[#out] = out[#out] .. (',' .. str[1])
        end
    end
    out[#out+1] = ']'
end

local function stringify_table(out, n, value)
    out[#out+1] = '{'
    for k, v in pairs(value) do
        assert(type(k) == 'string')
        local str = {}
        stringify_value(str, n, v)
        out[#out+1] = k .. ':' .. str[1]
        table.move(str, 2, #str, #out+1, out)
    end
    out[#out+1] = '}'
end

function stringify_value(out, n, value)
    local vt = type(value)
    assert(vt ~= 'function' and vt ~= 'userdata')
    if vt ~= 'table' then
        if vt == 'string' and value:match ' ' then
            out[#out+1] = ('%q'):format(value)
        else
            out[#out+1] = tostring(value)
        end
        return
    end
    local fk, fv = next(value)
    if not fk then
        -- empty table
        out[#out+1] = '{}'
        return
    end
    if type(fk) == 'number' then
        if type(fv) == 'table' then
            stringify_array(out, n + 1, value)
        else
            stringify_simple_array(out, n + 1, value)
        end
        return 
    end
    stringify_table(out, n + 1, value)
end

local function stringify_entity(out, e)
    for _, v in ipairs(e) do
        out[#out+1] = '[' .. v[1]
        stringify_value(out, 4, v[2])
        out[#out+1] = ']'
    end
end

local function stringify(t)
    local out = {}
    for _, e in ipairs(t) do
        out[#out+1] = '['
        stringify_entity(out, e)
        out[#out+1] = ']'
    end
    return table.concat(out, '\n')
end

return stringify
