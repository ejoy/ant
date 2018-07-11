local rdebug = require 'remotedebug'
local source = require 'new-debugger.worker.source'

local varPool = {}

local VAR_LOCAL = 0xFFFF
local VAR_VARARG = 0xFFFE
local VAR_UPVALUE = 0xFFFD
local VAR_GLOBAL = 0xFFFC
local VAR_STANDARD = 0xFFFB

local standard = {}
for _, v in ipairs{
    "ipairs",
    "error",
    "utf8",
    "rawset",
    "tostring",
    "select",
    "tonumber",
    "_VERSION",
    "loadfile",
    "xpcall",
    "string",
    "rawlen",
    "ravitype",
    "print",
    "rawequal",
    "setmetatable",
    "require",
    "getmetatable",
    "next",
    "package",
    "coroutine",
    "io",
    "_G",
    "math",
    "collectgarbage",
    "os",
    "table",
    "ravi",
    "dofile",
    "pcall",
    "load",
    "module",
    "rawget",
    "debug",
    "assert",
    "type",
    "pairs",
    "bit32",
} do
    standard[v] = true
end

local function hasLocal(frameId)
    local i = 1
    while true do
        local name = rdebug.getlocal(frameId, i)
        if name == nil then
            return false
        end
        if name ~= '(*temporary)' then
            return true
        end
        i = i + 1
    end
end

local function hasVararg(frameId)
    return rdebug.getlocal(frameId, -1) ~= nil
end

local function hasUpvalue(frameId)
    local f = rdebug.getfunc(frameId)
    return rdebug.getupvalue(f, 1) ~= nil
end

local function hasGlobal()
    local gt = rdebug._G
    local key
    while true do
        key = rdebug.next(gt, key)
        if key == nil then
            return false
        end
        if not standard[rdebug.value(key)] then
            return true
        end
    end
end

local function hasStandard()
    return true
end

local function varCanExtand(type, subtype, value)
    if type == 'function' then
        return rdebug.getupvalue(value, 1) ~= nil
    elseif type == 'table' then
        if rdebug.next(value, nil) ~= nil then
            return true
        end
        if rdebug.getmetatable(value) ~= nil then
            return true
        end
        return false
    elseif type == 'userdata' then
        if rdebug.getmetatable(value) ~= nil then
            return true
        end
        if subtype == 'full' and rdebug.getuservalue(value) ~= nil then
            return true
        end
        return false
    end
    return false
end

local function varGetName(value)
    local type, subtype = rdebug.type(value)
    if type == 'string' then
        local str = rdebug.value(value)
        if #str < 32 then
            return str
        end
        return str:sub(1, 32) .. '...'
    elseif type == 'boolean' then
        if rdebug.value(value) then
            return 'true'
        else
            return 'false'
        end
    elseif type == 'nil' then
        return 'nil'
    elseif type == 'number' then
        if subtype == 'integer' then
            local rvalue = rdebug.value(value)
            if rvalue > 0 and rvalue < 1000 then
                return ('[%03d]'):format(rvalue)
            end
            return ('%d'):format(rvalue)
        else
            return ('%.4f'):format(rdebug.value(value))
        end
    elseif type == 'function' then
        --TODO
    elseif type == 'table' then
        --TODO
    elseif type == 'userdata' then
        --TODO
    end
    return tostring(rdebug.value(value))
end

local function varGetShortValue(value)
    local type, subtype = rdebug.type(value)
    if type == 'string' then
        local str = rdebug.value(value)
        if #str < 16 then
            return ("'%s'"):format(str)
        end
        return ("'%s...'"):format(str:sub(1, 16))
    elseif type == 'boolean' then
        if rdebug.value(value) then
            return 'true'
        else
            return 'false'
        end
    elseif type == 'nil' then
        return 'nil'
    elseif type == 'number' then
        if subtype == 'integer' then
            return ('%d'):format(rdebug.value(value))
        else
            return ('%f'):format(rdebug.value(value))
        end
    elseif type == 'function' then
        return 'func'
    elseif type == 'table' then
        if varCanExtand(type, subtype, value) then
            return "..."
        end
        return '{}'
    elseif type == 'userdata' then
        return 'userdata'
    end
    return type
end

local TABLE_VALUE_MAXLEN = 32
local function varGetTableValue(t)
    local str = ''
    local mark = {}
    local i = 1
    while true do
        local v = rdebug.index(t, i)
        if v == nil then
            break
        end
        if str == '' then
            str = varGetShortValue(v)
        else
            str = str .. "," .. varGetShortValue(v)
        end
        mark[i] = true
        if #str >= TABLE_VALUE_MAXLEN then
            return ("{%s...}"):format(str)
        end
    end

    local kvs = {}
    local key, value
    while true do
        key, value = rdebug.next(t, key)
        if key == nil then
            break
        end
        local _, subtype = rdebug.type(key)
        if subtype == 'integer' and mark[rdebug.value(key)] then
            goto continue
        end
        local kn = varGetName(key)
        kvs[#kvs + 1] = { kn, value }
        if #kvs >= 300 then
            break
        end
        ::continue::
    end
    table.sort(kvs, function(a, b) return a[1] < b[1] end)

    for _, kv in ipairs(kvs) do
        if str == '' then
            str = kv[1] .. '=' .. varGetShortValue(kv[2])
        else
            str = str .. ',' .. kv[1] .. '=' .. varGetShortValue(kv[2])
        end
        if #str >= TABLE_VALUE_MAXLEN then
            return ("{%s...}"):format(str)
        end
    end
    return ("{%s}"):format(str)
end

local function getLineStart(str, pos, n)
    for _ = 1, n - 1 do
        local f, _, nl1, nl2 = str:find('([\n\r])([\n\r]?)', pos)
        if not f then
            return
        end
        if nl1 == nl2 then
            pos = f + 1
        elseif nl2 == '' then
            pos = f + 1
        else
            pos = f + 2
        end
    end
    return pos
end

local function getLineEnd(str, pos, n)
    local pos = getLineStart(str, pos, n)
    if not pos then
        return
    end
    local pos = str:find('[\n\r]', pos)
    if not pos then
        return
    end
    return pos - 1
end

local function getFunctionCode(str, startLn, endLn)
    local startPos = getLineStart(str, 1, startLn)
    if not startPos then
        return str
    end
    local endPos = getLineEnd(str, startPos, endLn - startLn + 1)
    if not endPos then
        return str:sub(startPos)
    end
    return str:sub(startPos, endPos)
end

local function varGetValue(type, subtype, value)
    if type == 'string' then
        local str = rdebug.value(value)
        if #str < 256 then
            return ("'%s'"):format(str)
        end
        return ("'%s...'"):format(str:sub(1, 256))
    elseif type == 'boolean' then
        if rdebug.value(value) then
            return 'true'
        else
            return 'false'
        end
    elseif type == 'nil' then
        return 'nil'
    elseif type == 'number' then
        if subtype == 'integer' then
            return ('%d'):format(rdebug.value(value))
        else
            return ('%f'):format(rdebug.value(value))
        end
    elseif type == 'function' then
        if subtype == 'c' then
            return 'C function'
        end
        local info = rdebug.getinfo(value)
        if not info then
            return tostring(rdebug.value(value))
        end
        local src = source.create(info.source)
        if not source.valid(src) then
            return tostring(rdebug.value(value))
        end
        if src.path then
            -- TODO: fs.relative
            return ("%s:%d"):format(src.path, info.linedefined)
        end
        local code = source.getCode(src.ref)
        return getFunctionCode(code, info.linedefined, info.lastlinedefined)
    elseif type == 'table' then
        return varGetTableValue(value)
    elseif type == 'userdata' then
        local meta = rdebug.getmetatable(value)
        if meta then
            local name = rdebug.index(meta, '__name')
            if name then
                return 'userdata: ' .. tostring(rdebug.value(name))
            end
        end
        return 'userdata'
    end
    return tostring(rdebug.value(value))
end

local function varCreateReference(frameId, value, evaluateName)
    local type, subtype = rdebug.type(value)
    local text = varGetValue(type, subtype, value)
    if varCanExtand(type, subtype, value) then
        local pool = varPool[frameId]
        pool[#pool + 1] = { value, evaluateName }
        return text, type, (frameId << 16) | #pool
    end
    return text, type
end

local function varCreate(frameId, name, value, evaluateName)
    local text, type, ref = varCreateReference(frameId, value, evaluateName)
    return {
        name = name,
        type = type,
        value = text,
        variablesReference = ref,
        evaluateName = evaluateName,
    }
end

local function getTabelKey(key)
    local type = rdebug.type(key)
    if type == 'string' then
        local str = rdebug.value(key)
        if str:match '^[_%a][_%w]*$' then
            return ('.%s'):format(str)
        end
        return ('[%q]'):format(str)
    elseif type == 'boolean' then
        return ('[%s]'):format(tostring(rdebug.value(key)))
    elseif type == 'number' then
        return ('[%s]'):format(tostring(rdebug.value(key)))
    end
end

local function extandTable(frameId, t, evaluateName)
    local vars = {}
    local key, value
    while true do
        key, value = rdebug.next(t, key)
        if key == nil then
            break
        end
        vars[#vars + 1] = varCreate(frameId, varGetName(key), value, ('%s%s'):format(evaluateName, getTabelKey(key)))
    end
    table.sort(vars, function(a, b) return a.name < b.name end)

    local meta = rdebug.getmetatable(t)
    if meta then
        table.insert(vars, 1, varCreate(frameId, '[metatable]', meta, ('debug.getmetatable(%s)'):format(evaluateName)))
    end
    return vars
end

local function extandFunction(frameId, f, evaluateName)
    local vars = {}
    local i = 1
    while true do
        local name, value = rdebug.getupvalue(f, i)
        if name == nil then
            break
        end
        vars[#vars + 1] = varCreate(frameId, name, value, ('debug.getupvalue(%s,%d)'):format(evaluateName, i))
        i = i + 1
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

local function extandUserdata(frameId, u, evaluateName)
    local vars = {}
    --TODO
    local uv = rdebug.getuservalue(u)
    if uv then
        table.insert(vars, 1, varCreate(frameId, '[uservalue]', uv, ('debug.getuservalue(%s)'):format(evaluateName)))
    end
    local meta = rdebug.getmetatable(u)
    if meta then
        table.insert(vars, 1, varCreate(frameId, '[metatable]', meta, ('debug.getmetatable(%s)'):format(evaluateName)))
    end
    return vars
end

local function extandValue(frameId, value, evaluateName)
    local type = rdebug.type(value)
    if type == 'table' then
        return extandTable(frameId, value, evaluateName)
    elseif type == 'function' then
        return extandFunction(frameId, value, evaluateName)
    elseif type == 'userdata' then
        return extandUserdata(frameId, value, evaluateName)
    end
    return {}
end

local extand = {}

extand[VAR_LOCAL] = function(frameId)
    local maps = {}
    local vars = {}
    local i = 1
    while true do
        local name, value = rdebug.getlocal(frameId, i)
        if name == nil then
            break
        end
        if name ~= '(*temporary)' then
            if maps[name] then
                vars[maps[name]] = varCreate(frameId, name, value, ('debug.getlocal(%d,%d,%q)'):format(frameId, i, name))
            else
                vars[#vars + 1] = varCreate(frameId, name, value, ('debug.getlocal(%d,%d,%q)'):format(frameId, i, name))
                maps[name] = #vars
            end
        end
        i = i + 1
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

extand[VAR_VARARG] = function(frameId)
    local vars = {}
    local i = -1
    while true do
        local name, value = rdebug.getlocal(frameId, i)
        if name == nil then
            break
        end
        vars[#vars + 1] = varCreate(frameId, ('[%d]'):format(-i), value, ('debug.getlocal(%d,%d)'):format(frameId, -i))
        i = i - 1
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

extand[VAR_UPVALUE] = function(frameId)
    local maps = {}
    local vars = {}
    local i = 1
    local f = rdebug.getfunc(frameId)
    while true do
        local name, value = rdebug.getupvalue(f, i)
        if name == nil then
            break
        end
        if maps[name] then
            vars[maps[name]] = varCreate(frameId, name, value, ('debug.getupvalue(%d,%d,%q)'):format(frameId, i, name))
        else
            vars[#vars + 1] = varCreate(frameId, name, value, ('debug.getupvalue(%d,%d,%q)'):format(frameId, i, name))
            maps[name] = #vars
        end
        i = i + 1
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

extand[VAR_GLOBAL] = function(frameId)
    local vars = {}
    local gt = rdebug._G
    local key, value
    while true do
        key, value = rdebug.next(gt, key)
        if key == nil then
            break
        end
        local name = varGetName(key)
        if not standard[name] then
            vars[#vars + 1] = varCreate(frameId, name, value, ('_G%s'):format(getTabelKey(key)))
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

extand[VAR_STANDARD] = function(frameId)
    local vars = {}
    local gt = rdebug._G
    local key, value
    while true do
        key, value = rdebug.next(gt, key)
        if key == nil then
            break
        end
        local name = varGetName(key)
        if standard[name] then
            vars[#vars + 1] = varCreate(frameId, name, value, ('_G%s'):format(getTabelKey(key)))
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

local m = {}

function m.scopes(frameId)
    local scopes = {}
    if hasLocal(frameId) then
        scopes[#scopes + 1] = {
            name = "Locals",
            variablesReference = (frameId << 16) | VAR_LOCAL,
            expensive = false,
        }
    end
    if hasVararg(frameId) then
        scopes[#scopes + 1] = {
            name = "Var Args",
            variablesReference = (frameId << 16) | VAR_VARARG,
            expensive = false,
        }
    end
    if hasUpvalue(frameId) then
        scopes[#scopes + 1] = {
            name = "Upvalues",
            variablesReference = (frameId << 16) | VAR_UPVALUE,
            expensive = false,
        }
    end
    if hasGlobal(frameId) then
        scopes[#scopes + 1] = {
            name = "Globals",
            variablesReference = (frameId << 16) | VAR_GLOBAL,
            expensive = true,
        }
    end
    if hasStandard(frameId) then
        scopes[#scopes + 1] = {
            name = "Standard",
            variablesReference = (frameId << 16) | VAR_STANDARD,
            expensive = true,
        }
    end
    if not varPool[frameId] then
        varPool[frameId] = {}
    end
    return scopes
end

function m.variables(frameId, valueId)
    if not varPool[frameId] then
        return nil, 'Error retrieving stack frame ' .. frameId
    end
    if extand[valueId] then
        return extand[valueId](frameId)
    end
    local pool = varPool[frameId]
    if not pool then
        return nil, 'Error variablesReference'
    end
    return extandValue(frameId, pool[valueId][1], pool[valueId][2])
end

function m.clean()
    varPool = {}
end

function m.createRef(frameId, value, evaluateName)
    if not varPool[frameId] then
        varPool[frameId] = {}
    end
    return varCreateReference(frameId, value, evaluateName)
end

return m
