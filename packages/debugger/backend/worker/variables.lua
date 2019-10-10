local rdebug = require 'remotedebug.visitor'
local source = require 'backend.worker.source'
local luaver = require 'backend.worker.luaver'
local ev = require 'common.event'

local varPool = {}

local VAR_LOCAL = 0xFFFF
local VAR_VARARG = 0xFFFE
local VAR_UPVALUE = 0xFFFD
local VAR_GLOBAL = 0xFFFC
local VAR_STANDARD = 0xFFFB

local MAX_TABLE_FIELD = 300

local TEMPORARY = "(temporary)"

local LUAVERSION = 54

local standard = {}

local function init_standard()
    local lstandard = {
        "_G",
        "_VERSION",
        "assert",
        "collectgarbage",
        "coroutine",
        "debug",
        "dofile",
        "error",
        "getmetatable",
        "io",
        "ipairs",
        "load",
        "loadfile",
        "math",
        "next",
        "os",
        "package",
        "pairs",
        "pcall",
        "print",
        "rawequal",
        "rawget",
        "rawset",
        "require",
        "select",
        "setmetatable",
        "string",
        "table",
        "tonumber",
        "tostring",
        "type",
        "xpcall",
    }

    if LUAVERSION == 51 then
        table.insert(lstandard, "gcinfo")
        table.insert(lstandard, "getfenv")
        table.insert(lstandard, "loadstring")
        table.insert(lstandard, "module")
        table.insert(lstandard, "newproxy")
        table.insert(lstandard, "setfenv")
        table.insert(lstandard, "unpack")
    end
    if LUAVERSION >= 52 then
        table.insert(lstandard, "rawlen")
    end
    if LUAVERSION == 52 or LUAVERSION == 53 then
        table.insert(lstandard, "bit32")
    end
    if LUAVERSION >= 53 then
        table.insert(lstandard, "utf8")
    end
    if LUAVERSION >= 54 then
        table.insert(lstandard, "warn")
    end
    standard = {}
    for _, v in ipairs(lstandard) do
        standard[v] = true
    end
end

ev.on('initializing', function()
    LUAVERSION = luaver.LUAVERSION
    init_standard()
    TEMPORARY = LUAVERSION >= 54 and "(temporary)" or "(*temporary)"
end)


local function hasLocal(frameId)
    local i = 1
    while true do
        local name = rdebug.getlocalv(frameId, i)
        if name == nil then
            return false
        end
        if name ~= TEMPORARY then
            return true
        end
        i = i + 1
    end
end

local function hasVararg(frameId)
    return rdebug.getlocalv(frameId, -1) ~= nil
end

local function hasUpvalue(frameId)
    local f = rdebug.getfunc(frameId)
    return rdebug.getupvaluev(f, 1) ~= nil
end

local function hasGlobal()
    local gt = rdebug._G
    local key
    while true do
        key = rdebug.nextv(gt, key)
        if not key then
            return false
        end
        if not standard[key] then
            return true
        end
    end
end

local function hasStandard()
    return true
end


local function normalizeNumber(str)
    if str:find('.', 1, true) then
        str = str:gsub('0+$', '')
        if str:sub(-1) == '.' then
            return str .. '0'
        end
    end
    return str
end


local function varCanExtand(type, subtype, value)
    if type == 'function' then
        return rdebug.getupvaluev(value, 1) ~= nil
    elseif type == 'table' then
        if rdebug.nextv(value, nil) ~= nil then
            return true
        end
        if rdebug.getmetatablev(value) ~= nil then
            return true
        end
        return false
    elseif type == 'userdata' then
        if rdebug.getmetatablev(value) ~= nil then
            return true
        end
        if subtype == 'full' and rdebug.getuservaluev(value) ~= nil then
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
        if LUAVERSION <= 52 then
            local rvalue = rdebug.value(value)
            if rvalue == math.floor(rvalue) then
                subtype = 'integer'
            end
        end
        if subtype == 'integer' then
            local rvalue = rdebug.value(value)
            if rvalue > 0 and rvalue < 1000 then
                return ('[%03d]'):format(rvalue)
            end
            return ('%d'):format(rvalue)
        else
            return normalizeNumber(('%.4f'):format(rdebug.value(value)))
        end
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
            return normalizeNumber(('%f'):format(rdebug.value(value)))
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
    elseif type == 'thread' then
        return 'thread'
    end
    return type
end

local TABLE_VALUE_MAXLEN = 32
local function varGetTableValue(t)
    local loct = rdebug.copytable(t,MAX_TABLE_FIELD)
    local str = ''
    local mark = {}
    for i, v in ipairs(loct) do
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
    for key, value in pairs(loct) do
        if mark[key] then
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

-- context: getvalue,setvalue,scopes,hover,watch,repl,copyvalue
local function varGetValue(context, type, subtype, value)
    if type == 'string' then
        local str = rdebug.value(value)
        if context == "repl" or context == "copyvalue" then
            return ("'%s'"):format(str)
        end
        if context == "hover" then
            if #str < 2048 then
                return ("'%s'"):format(str)
            end
            return ("'%s...'"):format(str:sub(1, 2048))
        end
        if #str < 1024 then
            return ("'%s'"):format(str)
        end
        return ("'%s...'"):format(str:sub(1, 1024))
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
            return normalizeNumber(('%f'):format(rdebug.value(value)))
        end
    elseif type == 'function' then
        if subtype == 'c' then
            return 'C function'
        end
        local info = rdebug.getinfo(value, "S")
        if not info then
            return tostring(rdebug.value(value))
        end
        local src = source.create(info.source)
        if not source.valid(src) then
            return tostring(rdebug.value(value))
        end
        if not src.sourceReference then
            return ("%s:%d"):format(source.clientPath(src.path), info.linedefined)
        end
        local code = source.getCode(src.sourceReference)
        return getFunctionCode(code, info.linedefined, info.lastlinedefined)
    elseif type == 'table' then
        return varGetTableValue(value)
    elseif type == 'userdata' then
        local meta = rdebug.getmetatablev(value)
        if meta ~= nil then
            local fn = rdebug.indexv(meta, '__debugger_tostring')
            if fn ~= nil and rdebug.type(fn) == 'function' then
                local ok, res = rdebug.evalref(fn, value)
                if ok then
                    return res
                end
            end
            local name = rdebug.indexv(meta, '__name')
            if name ~= nil then
                return 'userdata: ' .. tostring(rdebug.value(name))
            end
        end
        if subtype == 'light' then
            return 'light' .. tostring(rdebug.value(value))
        end
        return 'userdata'
    elseif type == 'thread' then
        return 'thread'
    end
    return tostring(rdebug.value(value))
end

local function varGetType(type, subtype)
    if type == 'string'
        or type == 'boolean'
        or type == 'nil'
        or type == 'table'
        or type == 'table'
        or type == 'thread'
    then
        return type
    elseif type == 'number' then
        return subtype
    elseif type == 'function' then
        if subtype == 'c' then
            return 'C function'
        end
        return 'function'
    elseif type == 'userdata' then
        if subtype == 'light' then
            return 'lightuserdata'
        end
        return 'userdata'
    end
    return type
end

local function varCreateReference(frameId, value, evaluateName, context)
    local type, subtype = rdebug.type(value)
    local textType = varGetType(type, subtype)
    local textValue = varGetValue(context, type, subtype, value)
    if varCanExtand(type, subtype, value) then
        varPool[#varPool + 1] = {
            v = value,
            eval  = evaluateName,
            frameId = frameId,
        }
        return textValue, textType, #varPool
    end
    return textValue, textType
end

local function varCreateSpecialReference(frameId, special)
    varPool[#varPool + 1] = {
        v = {},
        special = special,
        frameId = frameId,
    }
    return #varPool
end

local function varCreateObject(frameId, name, value, evaluateName)
    local text, type, ref = varCreateReference(frameId, value, evaluateName, "getvalue")
    local var = {
        name = name,
        type = type,
        value = text,
        variablesReference = ref,
        evaluateName = evaluateName and evaluateName or nil,
    }
    return var
end

local function varCreate(vars, frameId, varRef, name, value, evaluateName, calcValue)
    local var = varCreateObject(frameId, name, value, evaluateName)
    local maps = varRef[3]
    if maps[name] then
        local log = require 'common.log'
        log.warn(false, "same name variables: "..name)
        vars[maps[name][3]] = var
        maps[name][1] = calcValue
    else
        vars[#vars + 1] = var
        maps[name] = { calcValue, evaluateName, #vars }
    end
    return var
end

local function varCreateInsert(vars, frameId, varRef, name, value, evaluateName, calcValue)
    local var = varCreateObject(frameId, name, value, evaluateName)
    var.presentationHint = {
        kind = "virtual"
    }
    local maps = varRef[3]
    if maps[name] then
        local log = require 'common.log'
        log.warn(false, "same name variables: "..name)
        table.remove(vars, maps[name][3])
    end
    table.insert(vars, 1, var)
    maps[name] = { calcValue, evaluateName }
    return var
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

local function extandTable(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local t = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local loct = rdebug.copytable(t,MAX_TABLE_FIELD)
    for key, value in pairs(loct) do
        local evalKey = getTabelKey(key)
        varCreate(vars, frameId, varRef, varGetName(key), value
            , evaluateName and evalKey and ('%s%s'):format(evaluateName, evalKey)
            , function() return rdebug.index(t, key) end
        )
    end
    table.sort(vars, function(a, b) return a.name < b.name end)

    local meta = rdebug.getmetatablev(t)
    if meta ~= nil then
        varCreateInsert(vars, frameId, varRef, '[metatable]', meta
            , evaluateName and ('debug.getmetatable(%s)'):format(evaluateName)
            , function() return rdebug.getmetatable(t) end
        )
    end
    return vars
end

local function extandFunction(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local f = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local i = 1
    local _, subtype = rdebug.type(f)
    local isCFunction = subtype == "c"
    while true do
        local name, value = rdebug.getupvaluev(f, i)
        if name == nil then
            break
        end
        local displayName = isCFunction and ("[%d]"):format(i) or name
        local fi = i
        local var = varCreate(vars, frameId, varRef, displayName, value
            , evaluateName and ('select(2, debug.getupvalue(%s,%d))'):format(evaluateName, i)
            , function() local _, r = rdebug.getupvalue(f, fi) return r end
        )
        var.presentationHint = {
            kind = "virtual"
        }
        i = i + 1
    end
    return vars
end

local function extandUserdata(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local u = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    if LUAVERSION >= 54 then
        local i = 1
        while true do
            local uv, ok = rdebug.getuservaluev(u, i)
            if not ok then
                break
            end
            if uv ~= nil then
                local fi = i
                local var = varCreate(vars, frameId, varRef, ('[uservalue:%d]'):format(i), uv
                    , evaluateName and ('debug.getuservalue(%s,%d)'):format(evaluateName,i)
                    , function() return rdebug.getuservalue(u, fi) end
                )
                var.presentationHint = {
                    kind = "virtual"
                }
            end
            i = i + 1
        end
    else
        local uv = rdebug.getuservaluev(u)
        if uv ~= nil then
            varCreateInsert(vars, frameId, varRef, '[uservalue]', uv
                , evaluateName and ('debug.getuservalue(%s)'):format(evaluateName)
                , function() return rdebug.getuservalue(u) end
            )
        end
    end

    local meta = rdebug.getmetatablev(u)
    if meta ~= nil then
        varCreateInsert(vars, frameId, varRef, '[metatable]', meta
            , evaluateName and ('debug.getmetatable(%s)'):format(evaluateName)
            , function() return rdebug.getmetatable(u) end
        )
    end
    return vars
end

local function extandValue(varRef)
    local type = rdebug.type(varRef.v)
    if type == 'table' then
        return extandTable(varRef)
    elseif type == 'function' then
        return extandFunction(varRef)
    elseif type == 'userdata' then
        return extandUserdata(varRef)
    end
    return {}
end

local function setValue(varRef, name, value)
    local maps = varRef[3]
    if not maps or not maps[name] then
        return nil, 'Failed set variable'
    end
    local frameId = varRef.frameId
    local rvalue = maps[name][1]()
    local newvalue
    if value == 'nil' then
        newvalue = nil
    elseif value == 'false' then
        newvalue = false
    elseif value == 'true' then
        newvalue = true
    elseif value:sub(1,1) == "'" and value:sub(-1,-1) == "'" then
        newvalue = value:sub(2,-2)
    elseif value:sub(1,1) == '"' and value:sub(-1,-1) == '"' then
        newvalue = value:sub(2,-2)
    elseif tonumber(value) then
        newvalue = tonumber(value)
    else
        newvalue = value
    end
    if not rdebug.assign(rvalue, newvalue) then
        return nil, 'Failed set variable'
    end
    local text, type = varCreateReference(frameId, rvalue, maps[name][2], "setvalue")
    return {
        value = text,
        type = type,
    }
end

local extand = {}

extand[VAR_LOCAL] = function(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local tempVar = {}
    local vars = {}
    local i = 1
    while true do
        local name, value = rdebug.getlocalv(frameId, i)
        if name == nil then
            break
        end
        if name ~= TEMPORARY then
            if name:sub(1,1) == "(" then
                tempVar[name] = tempVar[name] and (tempVar[name] + 1) or 1
                name = ("(%s #%d)"):format(name:sub(2,-2), tempVar[name])
            end
            local fi = i
            varCreate(vars, frameId, varRef, name, value
                , name
                , function() local _, r = rdebug.getlocal(frameId, fi) return r end
            )
        end
        i = i + 1
    end

    if LUAVERSION >= 54 then
        local info = {}
        rdebug.getinfo(frameId, "r", info)
        if info.ftransfer > 0 and info.ntransfer > 0 then
            for i = info.ftransfer, info.ftransfer + info.ntransfer do
                local name, value = rdebug.getlocalv(frameId, i)
                if name ~= nil then
                    name = ("(return #%d)"):format(i - info.ftransfer + 1)
                    local fi = i
                    varCreate(vars, frameId, varRef, name, value
                        , name
                        , function() local _, r = rdebug.getlocal(frameId, fi) return r end
                    )
                end
            end
        end
    end

    return vars
end

extand[VAR_VARARG] = function(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local vars = {}
    local i = -1
    while true do
        local name, value = rdebug.getlocalv(frameId, i)
        if name == nil then
            break
        end
        local fi = i
        varCreate(vars, frameId, varRef, ('[%d]'):format(-i), value
            , ('select(%d,...)'):format(i)
            , function() local _, r = rdebug.getlocal(frameId, fi) return r end
        )
        i = i - 1
    end
    return vars
end

extand[VAR_UPVALUE] = function(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local vars = {}
    local i = 1
    local f = rdebug.getfunc(frameId)
    while true do
        local name, value = rdebug.getupvaluev(f, i)
        if name == nil then
            break
        end
        local fi = i
        varCreate(vars, frameId, varRef, name, value
            , name
            , function() local _, r = rdebug.getupvalue(f, fi) return r end
        )
        i = i + 1
    end
    return vars
end

extand[VAR_GLOBAL] = function(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local vars = {}
    local loct = rdebug.copytable(rdebug._G,MAX_TABLE_FIELD)
    for key, value in pairs(loct) do
        local name = varGetName(key)
        if not standard[name] then
            varCreate(vars, frameId, varRef, name
                , value, ('_G%s'):format(getTabelKey(key))
                , function() return rdebug.index(rdebug._G, key) end
            )
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

extand[VAR_STANDARD] = function(varRef)
    varRef[3] = {}
    local frameId = varRef.frameId
    local vars = {}
    local loct = rdebug.copytable(rdebug._G,MAX_TABLE_FIELD)
    for key, value in pairs(loct) do
        local name = varGetName(key)
        if standard[name] then
            varCreate(vars, frameId, varRef, name, value
                , ('_G%s'):format(getTabelKey(key))
                , function() return rdebug.index(rdebug._G, key) end
            )
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
            variablesReference = varCreateSpecialReference(frameId, VAR_LOCAL),
            expensive = false,
        }
    end
    if hasVararg(frameId) then
        scopes[#scopes + 1] = {
            name = "Varargs",
            variablesReference = varCreateSpecialReference(frameId, VAR_VARARG),
            expensive = false,
        }
    end
    if hasUpvalue(frameId) then
        scopes[#scopes + 1] = {
            name = "Upvalues",
            variablesReference = varCreateSpecialReference(frameId, VAR_UPVALUE),
            expensive = false,
        }
    end
    if hasGlobal() then
        scopes[#scopes + 1] = {
            name = "Globals",
            variablesReference = varCreateSpecialReference(frameId, VAR_GLOBAL),
            expensive = true,
        }
    end
    if hasStandard() then
        scopes[#scopes + 1] = {
            name = "Standard",
            variablesReference = varCreateSpecialReference(frameId, VAR_STANDARD),
            expensive = true,
        }
    end
    return scopes
end

function m.extand(valueId)
    local varRef = varPool[valueId]
    if not varRef then
        return nil, 'Error variablesReference'
    end
    if varRef.special then
        return extand[varRef.special](varRef)
    end
    return extandValue(varRef)
end

function m.set(valueId, name, value)
    local varRef = varPool[valueId]
    if not varRef then
        return nil, 'Error variablesReference'
    end
    return setValue(varRef, name, value)
end

function m.clean()
    varPool = {}
end

function m.createText(value, context)
    local type, subtype = rdebug.type(value)
    return varGetValue(context, type, subtype, value)
end

function m.createRef(frameId, value, evaluateName, context)
    local text, _, ref = varCreateReference(frameId, value, evaluateName, context)
    return text, ref
end

ev.on('terminated', function()
    m.clean()
end)

return m
