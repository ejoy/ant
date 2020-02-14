local rdebug = require 'remotedebug.visitor'
local source = require 'backend.worker.source'
local luaver = require 'backend.worker.luaver'
local ev = require 'common.event'

local SHORT_TABLE_FIELD = 100
local MAX_TABLE_FIELD = 1000
local LUAVERSION = 54

local info = {}
local varPool = {}
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
    elseif LUAVERSION == 52 then
        table.insert(lstandard, "rawlen")
        table.insert(lstandard, "bit32")
    elseif LUAVERSION == 53 then
        table.insert(lstandard, "rawlen")
        table.insert(lstandard, "bit32")
        table.insert(lstandard, "utf8")
    elseif LUAVERSION >= 54 then
        table.insert(lstandard, "rawlen")
        table.insert(lstandard, "utf8")
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
end)

local function isTemporary(name)
    if LUAVERSION >= 54 then
        return name == "(C temporary)" or name == "(temporary)"
    end
    return name == "(*temporary)"
end

local special_has = {}

function special_has.Parameter(frameId)
    if LUAVERSION >= 52 then
        rdebug.getinfo(frameId, "u", info)
        if info.nparams > 0 then
            return true
        end
    end
    return rdebug.getlocalv(frameId, -1) ~= nil
end

function special_has.Local(frameId)
    local i = 1
    --已经在Parameter里调用过getinfo 'u'
    if LUAVERSION >= 52 and info.nparams > 0 then
        i = i + info.nparams
    end
    while true do
        local name = rdebug.getlocalv(frameId, i)
        if name == nil then
            return false
        end
        if not isTemporary(name) then
            return true
        end
        i = i + 1
    end
end

function special_has.Upvalue(frameId)
    local f = rdebug.getfunc(frameId)
    return rdebug.getupvaluev(f, 1) ~= nil
end

function special_has.Return(frameId)
    rdebug.getinfo(frameId, "r", info)
    return info.ftransfer > 0 and info.ntransfer > 0
end

function special_has.Global()
    local gt = rdebug._G
    local key
    while true do
        key = rdebug.nextkey(gt, key)
        if not key then
            return false
        end
        if not standard[key] then
            return true
        end
    end
end

function special_has.Standard()
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


local function varCanExtand(type, value)
    if type == 'function' then
        return rdebug.getupvaluev(value, 1) ~= nil
    elseif type == 'c function' then
        return rdebug.getupvaluev(value, 1) ~= nil
    elseif type == 'table' then
        if rdebug.nextkey(value, nil) ~= nil then
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
        if rdebug.getuservaluev(value) ~= nil then
            return true
        end
        return false
    elseif type == 'lightuserdata' then
        if rdebug.getmetatablev(value) ~= nil then
            return true
        end
        return false
    end
    return false
end

local function varGetName(value)
    local type = rdebug.type(value)
    if LUAVERSION <= 52 and type == "float" then
        local rvalue = rdebug.value(value)
        if rvalue == math.floor(rvalue) then
            type = 'integer'
        end
    end
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
    elseif type == 'integer' then
        local rvalue = rdebug.value(value)
        if rvalue > 0 and rvalue < 1000 then
            return ('[%03d]'):format(rvalue)
        end
        return ('%d'):format(rvalue)
    elseif type == 'float' then
        return normalizeNumber(('%.4f'):format(rdebug.value(value)))
    end
    return tostring(rdebug.value(value))
end

local function varGetShortValue(value)
    local type = rdebug.type(value)
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
    elseif type == 'integer' then
        return ('%d'):format(rdebug.value(value))
    elseif type == 'float' then
        return normalizeNumber(('%f'):format(rdebug.value(value)))
    elseif type == 'function' then
        return 'func'
    elseif type == 'c function' then
        return 'func'
    elseif type == 'table' then
        if varCanExtand(type, value) then
            return "..."
        end
        return '{}'
    end
    return type
end

local TABLE_VALUE_MAXLEN = 32
local function varGetTableValue(t)
    local asize = rdebug.tablesize(t)
    local str = ''
    for i = 1, asize do
        local v = rdebug.indexv(t, i)
        if str == '' then
            str = varGetShortValue(v)
        else
            str = str .. "," .. varGetShortValue(v)
        end
        if #str >= TABLE_VALUE_MAXLEN then
            return ("{%s,...}"):format(str)
        end
    end

    local loct = rdebug.copytable(t,SHORT_TABLE_FIELD)
    local kvs = {}
    for i = 1, #loct, 3 do
        local key, value = loct[i], loct[i+1]
        local kn = varGetName(key)
        kvs[#kvs + 1] = { kn, value }
    end
    table.sort(kvs, function(a, b) return a[1] < b[1] end)

    for _, kv in ipairs(kvs) do
        if str == '' then
            str = kv[1] .. '=' .. varGetShortValue(kv[2])
        else
            str = str .. ',' .. kv[1] .. '=' .. varGetShortValue(kv[2])
        end
        if #str >= TABLE_VALUE_MAXLEN then
            return ("{%s,...}"):format(str)
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
local function varGetValue(context, type, value)
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
    elseif type == 'integer' then
        return ('%d'):format(rdebug.value(value))
    elseif type == 'float' then
        return normalizeNumber(('%f'):format(rdebug.value(value)))
    elseif type == 'function' then
        rdebug.getinfo(value, "S", info)
        local src = source.create(info.source)
        if not source.valid(src) then
            return tostring(rdebug.value(value))
        end
        if not src.sourceReference then
            return ("%s:%d"):format(source.clientPath(src.path), info.linedefined)
        end
        local code = source.getCode(src.sourceReference)
        return getFunctionCode(code, info.linedefined, info.lastlinedefined)
    elseif type == 'c function' then
        return 'C function'
    elseif type == 'table' then
        return varGetTableValue(value)
    elseif type == 'userdata' then
        local meta = rdebug.getmetatablev(value)
        if meta ~= nil then
            local fn = rdebug.fieldv(meta, '__debugger_tostring')
            if fn ~= nil and (rdebug.type(fn) == 'function' or rdebug.type(fn) == 'c function') then
                local ok, res = rdebug.evalref(fn, value)
                if ok then
                    return res
                end
            end
            local name = rdebug.fieldv(meta, '__name')
            if name ~= nil then
                return tostring(rdebug.value(name))
            end
        end
        return 'userdata'
    elseif type == 'lightuserdata' then
        return 'light' .. tostring(rdebug.value(value))
    elseif type == 'thread' then
        return 'thread'
    end
    return tostring(rdebug.value(value))
end

local function varCreateReference(value, evaluateName, context)
    local type = rdebug.type(value)
    local result = {
        type = type,
        value = varGetValue(context, type, value),
        variablesReference = 0,
    }
    if varCanExtand(type, value) then
        varPool[#varPool + 1] = {
            v = value,
            eval = evaluateName,
        }
        result.variablesReference = #varPool
        if type == "table" then
            local asize, hsize = rdebug.tablesize(value)
            result.indexedVariables = asize + 1
            result.namedVariables = hsize
        end
    end
    return result
end

local function varCreateScopes(frameId, scopes, name, expensive)
    if not special_has[name](frameId) then
        return
    end
    varPool[#varPool + 1] = {
        v = {},
        special = name,
        frameId = frameId,
    }
    scopes[#scopes + 1] = {
        name = name,
        variablesReference = #varPool,
        expensive = expensive,
    }
    if name == "Global" then
        local scope = scopes[#scopes]
        local asize, hsize = rdebug.tablesize(rdebug._G)
        scope.indexedVariables = asize + 1
        scope.namedVariables = hsize

        local var = varPool[#varPool]
        var.v = rdebug._G
        var.eval = "_G"
    end
end

local function varCreate(vars, varRef, kind, name, nameidx, value, evaluateName, calcValue)
    local extand = varRef.extand
    if extand[name] then
        local index = extand[name][3]
        local nameidx = extand[name][4]
        local var = vars[index]
        if not nameidx or var.presentationHint then
            local log = require 'common.log'
            log.error("same name variables: "..name)
            return {}
        end
        local newname = ("%s #%d"):format(name, nameidx)
        if extand[newname] then
            local log = require 'common.log'
            log.error("same name variables: "..name)
            return {}
        end
        var.name = newname
        var.presentationHint = {
            kind = "virtual"
        }
        var.evaluateName = nil
        extand[newname] = extand[name]
        extand[newname][2] = nil
        extand[name] = nil
    end
    if type(evaluateName) ~= "string" then
        evaluateName = nil
    end
    local var = varCreateReference(value, evaluateName, "getvalue")
    var.name = name
    var.evaluateName = evaluateName
    var.presentationHint = kind and { kind = kind } or nil
    vars[#vars + 1] = var
    extand[name] = { calcValue, evaluateName, #vars, nameidx }
end

local function getTabelKey(key)
    local type = rdebug.type(key)
    if type == 'string' then
        local str = rdebug.value(key)
        if str:match '^[_%a][_%w]*$' then
            return ('.%s'):format(str)
        end
        return ('[%q]'):format(str)
    elseif type == 'boolean' or type == 'float' or type == 'integer' then
        return ('[%s]'):format(tostring(rdebug.value(key)))
    end
end

local function extandTableIndexed(varRef, start, count)
    varRef.extand = varRef.extand or {}
    local t = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local last = start + count - 1
    if start <= 0 then
        start = 1
    end
    for key = start, last do
        local value = rdebug.indexv(t, key)
        if value ~= nil then
            local name = (key > 0 and key < 1000) and ('[%03d]'):format(key) or ('%d'):format(key)
            varCreate(vars, varRef, nil
                , name, nil
                , value, evaluateName and ('%s[%d]'):format(evaluateName, key)
                , function() return rdebug.index(t, key) end
            )
        end
    end
    return vars
end

local function extandTableNamed(varRef)
    varRef.extand = varRef.extand or {}
    local t = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local loct = rdebug.copytable(t,MAX_TABLE_FIELD)
    for i = 1, #loct, 3 do
        local key, value, valueref = loct[i], loct[i+1], loct[i+2]
        local evalKey = getTabelKey(key)
        varCreate(vars, varRef, nil
            , varGetName(key), nil
            , value, evaluateName and evalKey and ('%s%s'):format(evaluateName, evalKey)
            , function() return valueref end
        )
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    local meta = rdebug.getmetatablev(t)
    if meta ~= nil then
        varCreate(vars, varRef, "virtual"
            , '[metatable]', nil
            , meta, evaluateName and ('debug.getmetatable(%s)'):format(evaluateName)
            , function() return rdebug.getmetatable(t) end
        )
        table.insert(vars, 1, vars[#vars])
        vars[#vars] = nil
    end
    return vars
end

local function extandTable(varRef, filter, start, count)
    if filter == 'indexed' then
        return extandTableIndexed(varRef, start, count)
    elseif filter == 'named' then
        return extandTableNamed(varRef)
    end
    return {}
end

local function extandFunction(varRef)
    varRef.extand = varRef.extand or {}
    local f = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local i = 1
    local isCFunction = rdebug.type(f) == "c function"
    while true do
        local name, value = rdebug.getupvaluev(f, i)
        if name == nil then
            break
        end
        local displayName = isCFunction and ("[%d]"):format(i) or name
        local fi = i
        varCreate(vars, varRef, "virtual"
            , displayName, nil
            , value, evaluateName and ('select(2, debug.getupvalue(%s,%d))'):format(evaluateName, i)
            , function() local _, r = rdebug.getupvalue(f, fi) return r end
        )
        i = i + 1
    end
    return vars
end

local function extandUserdata(varRef)
    varRef.extand = varRef.extand or {}
    local u = varRef.v
    local evaluateName = varRef.eval
    local vars = {}

    local meta = rdebug.getmetatablev(u)
    if meta ~= nil then
        varCreate(vars, varRef, "virtual"
            , '[metatable]', nil
            , meta, evaluateName and ('debug.getmetatable(%s)'):format(evaluateName)
            , function() return rdebug.getmetatable(u) end
        )
    end

    if LUAVERSION >= 54 then
        local i = 1
        while true do
            local uv, ok = rdebug.getuservaluev(u, i)
            if not ok then
                break
            end
            if uv ~= nil then
                local fi = i
                varCreate(vars, varRef, "virtual"
                    , ('[uservalue %d]'):format(i), nil
                    , uv, evaluateName and ('debug.getuservalue(%s,%d)'):format(evaluateName,i)
                    , function() return rdebug.getuservalue(u, fi) end
                )
            end
            i = i + 1
        end
    else
        local uv = rdebug.getuservaluev(u)
        if uv ~= nil then
            varCreate(vars, varRef, "virtual"
                , '[uservalue]', nil
                , uv, evaluateName and ('debug.getuservalue(%s)'):format(evaluateName)
                , function() return rdebug.getuservalue(u) end
            )
    end
    end
    return vars
end

local special_extand = {}

function special_extand.Local(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local tempVar = {}
    local vars = {}
    local i = 1
    if LUAVERSION >= 52 then
        rdebug.getinfo(frameId, "u", info)
        if info.nparams > 0 then
            i = i + info.nparams
        end
    end
    while true do
        local name, value = rdebug.getlocalv(frameId, i)
        if name == nil then
            break
        end
        if not isTemporary(name) then
            if name:sub(1,1) == "(" then
                tempVar[name] = tempVar[name] and (tempVar[name] + 1) or 1
                name = ("(%s #%d)"):format(name:sub(2,-2), tempVar[name])
            end
            local fi = i
            varCreate(vars, varRef, nil
                , name, i
                , value, name
                , function() local _, r = rdebug.getlocal(frameId, fi) return r end
            )
        end
        i = i + 1
    end
    return vars
end

function special_extand.Upvalue(varRef)
    varRef.extand = varRef.extand or {}
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
        varCreate(vars, varRef, nil
            , name, nil
            , value, name
            , function() local _, r = rdebug.getupvalue(f, fi) return r end
        )
        i = i + 1
    end
    return vars
end

function special_extand.Parameter(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local vars = {}

    if LUAVERSION >= 52 then
        rdebug.getinfo(frameId, "u", info)
        if info.nparams > 0 then
            for i = 1, info.nparams do
                local name, value = rdebug.getlocalv(frameId, i)
                if name ~= nil then
                    local fi = i
                    varCreate(vars, varRef, nil
                        , name, i
                        , value, name
                        , function() local _, r = rdebug.getlocal(frameId, fi) return r end
                    )
                end
            end
        end
    end

    local i = -1
    while true do
        local name, value = rdebug.getlocalv(frameId, i)
        if name == nil then
            break
        end
        local fi = i
        varCreate(vars, varRef, nil
            , ('[vararg %d]'):format(-i), nil
            , value, ('select(%d,...)'):format(-i)
            , function() local _, r = rdebug.getlocal(frameId, fi) return r end
        )
        i = i - 1
    end

    return vars
end

function special_extand.Return(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local vars = {}
    rdebug.getinfo(frameId, "r", info)
    if info.ftransfer > 0 and info.ntransfer > 0 then
        for i = info.ftransfer, info.ftransfer + info.ntransfer - 1 do
            local name, value = rdebug.getlocalv(frameId, i)
            if name ~= nil then
                local fi = i
                varCreate(vars, varRef, nil
                    , ('[%d]'):format(i - info.ftransfer + 1), nil
                    , value, nil
                    , function() local _, r = rdebug.getlocal(frameId, fi) return r end
                )
            end
        end
    end
    return vars
end

local function isStandardName(v)
    return rdebug.type(v) == 'string' and standard[rdebug.value(v)]
end

local function extandGlobalNamed(varRef)
    varRef.extand = varRef.extand or {}
    local vars = {}
    local loct = rdebug.copytable(rdebug._G,MAX_TABLE_FIELD)
    for i = 1, #loct, 3 do
        local key, value, valueref = loct[i], loct[i+1], loct[i+2]
        if not isStandardName(key) then
            varCreate(vars, varRef, nil
                , varGetName(key), nil
                , value, ('_G%s'):format(getTabelKey(key))
                , function() return valueref end
            )
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

function special_extand.Global(varRef, filter, start, count)
    if filter == 'indexed' then
        return extandTableIndexed(varRef, start, count)
    elseif filter == 'named' then
        return extandGlobalNamed(varRef)
    end
    return {}
end

function special_extand.Standard(varRef)
    varRef.extand = varRef.extand or {}
    local vars = {}
    for name in pairs(standard) do
        local value = rdebug.fieldv(rdebug._G, name)
        if value ~= nil then
            varCreate(vars, varRef, nil
                , name, nil
                , value , ('_G%s'):format(getTabelKey(name))
                , function() return rdebug.field(rdebug._G, name) end
            )
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

local function extandValue(varRef, filter, start, count)
    if varRef.special then
        return special_extand[varRef.special](varRef, filter, start, count)
    end
    local type = rdebug.type(varRef.v)
    if type == 'table' then
        return extandTable(varRef, filter, start, count)
    elseif type == 'function' then
        return extandFunction(varRef)
    elseif type == 'c function' then
        return extandFunction(varRef)
    elseif type == 'userdata' then
        return extandUserdata(varRef)
    end
    return {}
end

local function setValue(varRef, name, value)
    if not varRef.extand or not varRef.extand[name] then
        return nil, 'Failed set variable'
    end
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
    local calcValue, evaluateName = varRef.extand[name][1], varRef.extand[name][2]
    local rvalue = calcValue()
    if not rdebug.assign(rvalue, newvalue) then
        return nil, 'Failed set variable'
    end
    return varCreateReference(rvalue, evaluateName, "setvalue")
end

local m = {}

function m.scopes(frameId)
    local scopes = {}
    varCreateScopes(frameId, scopes, "Parameter", false)
    varCreateScopes(frameId, scopes, "Local", false)
    varCreateScopes(frameId, scopes, "Upvalue", false)
    if LUAVERSION >= 54 then
        varCreateScopes(frameId, scopes, "Return", false)
    end
    varCreateScopes(frameId, scopes, "Global", true)
    varCreateScopes(frameId, scopes, "Standard", true)
    return scopes
end

function m.extand(valueId, filter, start, count)
    local varRef = varPool[valueId]
    if not varRef then
        return nil, 'Error variablesReference'
    end
    return extandValue(varRef, filter, start, count)
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
    rdebug.cleanwatch()
end

function m.createText(value, context)
    local type = rdebug.type(value)
    return varGetValue(context, type, value)
end

function m.createRef(value, evaluateName, context)
    return varCreateReference(value, evaluateName, context)
end

function m.tostring(v)
    local meta = rdebug.getmetatablev(v)
    if meta ~= nil then
        local fn = rdebug.fieldv(meta, '__tostring')
        if fn ~= nil and (rdebug.type(fn) == 'function' or rdebug.type(fn) == 'c function') then
            local ok, res = rdebug.evalref(fn, v)
            if ok then
                return res
            end
        end
    end
    local type = rdebug.type(v)
    if type == 'integer' or
        type == 'float' or
        type == 'string' or
        type == 'boolean' or
        type == 'nil'
    then
        return tostring(rdebug.value(v))
    end
    if meta ~= nil then
        local name = rdebug.fieldv(meta, '__name')
        if name ~= nil then
            type = tostring(rdebug.value(name))
        end
    end
    return tostring(rdebug.value(v))
end

ev.on('terminated', function()
    m.clean()
end)

return m
