local rdebug = require 'remotedebug.visitor'

local NEWLINE <const> = '\n'
local INDENT  <const> = '    '
local DEPTH   <const> = 10

local level
local out
local visited

local putValue

local function floatToString(x)
    if x ~= x then
        return '0/0'
    end
    if x == math.huge then
        return 'math.huge'
    end
    if x == -math.huge then
        return '-math.huge'
    end
    local g = ('%.16g'):format(x)
    if tonumber(g) == x then
        return g
    end
    return ('%.17g'):format(x)
end

local function isIdentifier(str)
    return type(str) == 'string' and str:match( "^[_%a][_%a%d]*$" )
end

local TypeOrders = {
    ['number']   = 1, ['boolean']  = 2, ['string'] = 3, ['table'] = 4, ['function'] = 5, ['userdata'] = 6, ['thread'] = 7
}

local function sortKeys(a, b)
    a, b = a[1], b[1]
    local ta, tb = type(a), type(b)
    if ta == tb and (ta == 'string' or ta == 'number') then return a < b end
    local dta, dtb = TypeOrders[ta], TypeOrders[tb]
    if dta and dtb then return TypeOrders[ta] < TypeOrders[tb]
    elseif dta     then return true
    elseif dtb     then return false
    end
    return ta < tb
end

local function puts(text)
    out[#out+1] = text
end

local function newline()
    puts(NEWLINE)
    puts(INDENT:rep(level))
end

local function putKey(k)
    if isIdentifier(k) then return puts(k) end
    puts("[")
    putValue(k)
    puts("]")
end

local function putTable(t)
    local uniquekey = rdebug.value(t)
    if visited[uniquekey] then
        puts('<table>')
    elseif level >= DEPTH then
        puts('{...}')
    else
        visited[uniquekey] = true

        puts('{')
        level = level + 1

        local count = 0
        local asize = rdebug.tablesize(t)
        for i=1, asize do
            if count > 0 then puts(',') end
            puts(' ')
            putValue(rdebug.index(t, i))
            count = count + 1
        end

        local loct = rdebug.tablehashv(t)
        local kvs = {}
        for i = 1, #loct, 2 do
            local key, value = loct[i], loct[i+1]
            kvs[#kvs + 1] = { key, value }
        end
        table.sort(kvs, sortKeys)

        for i=1, #kvs do
            local kv = kvs[i]
            if count > 0 then puts(',') end
            newline()
            putKey(kv[1])
            puts(' = ')
            putValue(kv[2])
            count = count + 1
        end

        local metatable = rdebug.getmetatablev(t)
        if metatable then
            if count > 0 then puts(',') end
            newline()
            puts('<metatable> = ')
            putValue(metatable)
        end

        level = level - 1
        if #kvs > 0 or metatable then
            newline()
        elseif asize > 0 then
            puts(' ')
        end
        puts('}')
    end
end

function putValue(v)
    local tv = rdebug.type(v)
    if tv == 'string' then
        puts(("%q"):format(rdebug.value(v)))
    elseif tv == 'float' then
        puts(floatToString(rdebug.value(v)))
    elseif tv == 'integer' or tv == 'boolean' or tv == 'nil' then
        puts(tostring(rdebug.value(v)))
    elseif tv == 'table' then
        putTable(v)
    else
        puts('<'..tv..'>')
    end
end

return function (root)
    level   = 0
    out  = {}
    visited = {}
    putValue(root)
    return table.concat(out)
end
