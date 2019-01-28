local stringify_value

local function stringify_simple_array(out, n, value)
    local str = {}
    for _, v in ipairs(value) do
        assert(type(v) ~= 'table')
        stringify_value(str, 0, v)
    end
    out[#out+1] = ('  '):rep(n) .. ('{%s}'):format(table.concat(str, ','))
end

local function stringify_array(out, n, value)
    out[#out+1] = ('  '):rep(n)
    for _, v in ipairs(value) do
        out[#out+1] = ('  '):rep(n+1) .. '----------'
        stringify_value(out, n, v)
    end
end

local function stringify_table(out, n, value)
    out[#out+1] = ('  '):rep(n)
    for k, v in pairs(value) do
        assert(type(k) == 'string')
        local str = {}
        stringify_value(str, n, v)
        out[#out+1] = ('  '):rep(n + 1) .. k .. ':' .. str[1]:gsub('^[ ]*', '')
        table.move(str, 2, #str, #out+1, out)
    end
end

function stringify_value(out, n, value)
    local vt = type(value)
    assert(vt ~= 'function' and vt ~= 'userdata')
    if vt ~= 'table' then
        if vt == 'string' and value:match ' ' then
            out[#out+1] = ('  '):rep(n) .. ('%q'):format(value)
        else
            out[#out+1] = ('  '):rep(n) .. tostring(value)
        end
        return
    end
    local fk = next(value)
    if not fk then
        -- empty table
        out[#out+1] = ('  '):rep(n) .. '{}'
        return
    end
    if type(fk) == 'number' then
        if type(value[1]) ~= 'table' and type(value[2]) ~= 'table' then
            stringify_simple_array(out, n + 1, value)
        else
            stringify_array(out, n + 1, value)
        end
        return
    end
    stringify_table(out, n + 1, value)
end

local function stringify(t)
    local n = -2
    local out = {}
    stringify_value(out, n, t)
    return table.concat(out, '\n')
end

return stringify
