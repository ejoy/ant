local rdebug = require 'luadebug.visitor'
local source = require 'backend.worker.source'
local luaver = require 'backend.worker.luaver'
local serialize = require 'backend.worker.serialize'
local ev = require 'backend.event'
local base64 = require 'common.base64'
local eval = require 'backend.worker.eval'

local SHORT_TABLE_ARRAY <const> = 15
local SHORT_TABLE_HASH <const> = 100
local MAX_TABLE_HASH <const> = 1000
local TABLE_VALUE_MAXLEN <const> = 32
local LUAVERSION = 54
local isjit = false
local arrayBase = 1
local standard = {}

local info = {}
local varPool = {}
local memoryRefPool = {}
local globalCache = {}
local cfunctionInfo = {}

local showIntegerAsHex = false

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
    if isjit then
        table.insert(lstandard, "jit")
        table.insert(lstandard, "bit")
    end
    standard = {}
    for _, v in ipairs(lstandard) do
        standard[v] = true
    end
end

ev.on('initializing', function(config)
    showIntegerAsHex = config.configuration.variables.showIntegerAsHex
    LUAVERSION = luaver.LUAVERSION
    isjit = luaver.isjit
    arrayBase = isjit and 0 or 1
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
    rdebug.getinfo(frameId, "u", info)
    if info.nparams > 0 then
        return true
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
    rdebug.getinfo(frameId, "f", info)
    return rdebug.getupvaluev(info.func, 1) ~= nil
end

function special_has.Return(frameId)
    rdebug.getinfo(frameId, "r", info)
    return info.ftransfer > 0 and info.ntransfer > 0
end

function special_has.Global(frameId)
    rdebug.getinfo(frameId, "f", info)
    local eval, value = rdebug.getupvaluev(info.func, 1)
    if eval ~= "_ENV" then
        eval = "_G"
        value = rdebug._G
    end
    if eval == "_G" and globalCache._G then
        local t = globalCache._G
        globalCache[frameId] = t
        return #t.global > 0
    end
    local t = { global = {}, standard = {}, eval = eval, value = value }
    local asize = 0
    local loct = rdebug.tablehash(value, 0, MAX_TABLE_HASH)
    if loct then
        asize = rdebug.tablesize(value)
        for i = 1, #loct, 3 do
            local key = loct[i]
            if standard[key] then
                t.standard[#t.standard+1] = loct[i]
                t.standard[#t.standard+1] = loct[i+1]
                t.standard[#t.standard+1] = loct[i+2]
            else
                t.global[#t.global+1] = loct[i]
                t.global[#t.global+1] = loct[i+1]
                t.global[#t.global+1] = loct[i+2]
            end
        end
    end
    globalCache[frameId] = t
    if eval == "_G" then
        globalCache._G = t
    end
    return asize ~= 0 or #t.global > 0
end

function special_has.Standard(frameId)
    local t = globalCache[frameId]
    return #t.standard > 0
end

local function floatNormalize(str)
    if str:find('.', 1, true) then
        str = str:gsub('0+$', '')
        if str:sub(-1) == '.' then
            return str..'0'
        end
        return str
    else
        return str..".0"
    end
end

local function floatToShortString(v)
    local str = ('%.4f'):format(v)
    return floatNormalize(str)
end

local function floatToString(x)
    if x ~= x then
        return 'nan'
    end
    if x == math.huge then
        return '+inf'
    end
    if x == -math.huge then
        return '-inf'
    end
    local g = ('%.16g'):format(x)
    if tonumber(g) ~= x then
        g = ('%.17g'):format(x)
    end
    return floatNormalize(g)
end

local function formatInteger(v)
    if showIntegerAsHex then
        return ('0x%x'):format(rdebug.value(v))
    else
        return ('%d'):format(rdebug.value(v))
    end
end

local escape_char = {
    ["\\"..string.byte "\a"] = "\\".."a",
    ["\\"..string.byte "\b"] = "\\".."b",
    ["\\"..string.byte "\f"] = "\\".."f",
    ["\\"..string.byte "\n"] = "\\".."n",
    ["\\"..string.byte "\r"] = "\\".."r",
    ["\\"..string.byte "\t"] = "\\".."t",
    ["\\"..string.byte "\v"] = "\\".."v",
    ["\\"..string.byte "\\"] = "\\".."\\",
    ["\\"..string.byte "\""] = "\\".."\"",
}

local function quotedString(s)
    return ("%q"):format(s):sub(2, -2):gsub("\\[1-9][0-9]?", escape_char):gsub("\\\n", "\\n")
end

local function varCanExtand(type, value)
    if type == 'function' then
        return rdebug.getupvaluev(value, 1) ~= nil
    elseif type == 'c function' then
        return true
    elseif type == 'table' then
        local asize, hsize = rdebug.tablesize(value)
        if asize ~= 0 or hsize ~= 0 then
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
    elseif type == 'cdata' then
        return eval.ffi_reflect("canextand", value)
    end
    return false
end

local function varGetShortName(value)
    local type = rdebug.type(value)
    if LUAVERSION <= 52 and type == "float" then
        local rvalue = rdebug.value(value)
        ---@cast rvalue number
        if rvalue == math.floor(rvalue) then
            type = 'integer'
        end
    end
    if type == 'string' then
        local str = rdebug.value(value)
        ---@cast str string
        if #str < 32 then
            return str
        end
        return quotedString(str:sub(1, 32))..'...'
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
        return floatToShortString(rdebug.value(value))
    elseif type == 'cdata' or type == 'ctype' then
        return eval.ffi_reflect("shorttypename", value) or type
    end
    return tostring(rdebug.value(value))
end

local function varGetName(value)
    local type = rdebug.type(value)
    if LUAVERSION <= 52 and type == "float" then
        local rvalue = rdebug.value(value)
        ---@cast rvalue number
        if rvalue == math.floor(rvalue) then
            type = 'integer'
        end
    end
    if type == 'integer' then
        local rvalue = rdebug.value(value)
        if rvalue > 0 and rvalue < 1000 then
            return ('[%03d]'):format(rvalue)
        end
        return ('%d'):format(rvalue)
    elseif type == 'float' then
        return floatToString(rdebug.value(value))
    elseif type == 'string' then
        return quotedString(rdebug.value(value))
    elseif type == 'cdata' then
        return eval.ffi_reflect("shorttypename", value) or "cdata"
    elseif type == 'ctype' then
        local tt = eval.ffi_reflect("shorttypename", value)
        if not tt then
            return type
        end
        return "ctype("..tt..")"
    end
    return tostring(rdebug.value(value))
end

local function varGetShortUserdata(value)
    local meta = rdebug.getmetatablev(value)
    if meta ~= nil then
        local name = rdebug.fieldv(meta, '__name')
        if name ~= nil then
            return tostring(rdebug.value(name))
        end
    end
    return 'userdata'
end

local function varGetShortValue(value)
    local type = rdebug.type(value)
    if type == 'string' then
        local str = rdebug.value(value)
        ---@cast str string
        if #str < 16 then
            return ("'%s'"):format(quotedString(str))
        end
        return ("'%s...'"):format(quotedString(str:sub(1, 16)))
    elseif type == 'boolean' then
        if rdebug.value(value) then
            return 'true'
        else
            return 'false'
        end
    elseif type == 'nil' then
        return 'nil'
    elseif type == 'integer' then
        return formatInteger(value)
    elseif type == 'float' then
        return floatToShortString(rdebug.value(value))
    elseif type == 'function' then
        return 'func'
    elseif type == 'c function' then
        return 'func'
    elseif type == 'table' then
        if varCanExtand(type, value) then
            return "..."
        end
        return '{}'
    elseif type == 'userdata' then
        return varGetShortUserdata(value)
    elseif type == 'cdata' then
        return eval.ffi_reflect("shortvalue", value)
    end
    return type
end

local function varGetTableValue(t)
    local str = ''
    do
        local loct = rdebug.tablearrayv(t, 1 - arrayBase, SHORT_TABLE_ARRAY)
        for i = 1, #loct do
            local v = loct[i]
            if str == '' then
                str = varGetShortValue(v)
            else
                str = str..","..varGetShortValue(v)
            end
            if #str >= TABLE_VALUE_MAXLEN then
                return ("{%s,...}"):format(str)
            end
        end
    end

    do
        local loct = rdebug.tablehashv(t, 0, SHORT_TABLE_HASH)
        local kvs = {}
        for i = 1, #loct, 2 do
            local key, value = loct[i], loct[i + 1]
            local kn = varGetShortName(key)
            kvs[#kvs + 1] = { kn, value }
        end
        table.sort(kvs, function(a, b) return a[1] < b[1] end)
        for _, kv in ipairs(kvs) do
            if str == '' then
                str = kv[1]..'='..varGetShortValue(kv[2])
            else
                str = str..','..kv[1]..'='..varGetShortValue(kv[2])
            end
            if #str >= TABLE_VALUE_MAXLEN then
                return ("{%s,...}"):format(str)
            end
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

local function varGetFunctionCode(value)
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
end

local function varGetUserdata(value, allow_lazy)
    local meta = rdebug.getmetatablev(value)
    if meta ~= nil then
        local fn = rdebug.fieldv(meta, '__debugger_tostring')
        if fn ~= nil then
            local ok, res = rdebug.eval(fn, value)
            if ok then
                return res, "userdata"
            else
                return "__debugger_tostring error: "..res, "userdata"
            end
        end
        local fn = rdebug.fieldv(meta, '__tostring')
        if fn ~= nil then
            if allow_lazy then
                return 'userdata', "userdata", true
            else
                local ok, res = rdebug.eval(fn, value)
                if ok then
                    return res
                else
                    return "__tostring error: "..res, "userdata"
                end
            end
        end
        local name = rdebug.fieldv(meta, '__name')
        if name ~= nil then
            return tostring(rdebug.value(name)), "userdata"
        end
    end
    return 'userdata', "userdata"
end

-- context: variables,hover,watch,repl,clipboard
local function varGetValue(context, allow_lazy, value)
    local type = rdebug.type(value)
    if type == 'string' then
        local str = rdebug.value(value)
        ---@cast str string
        if context == "repl" or context == "clipboard" then
            return ("'%s'"):format(str), 'string'
        end
        if context == "hover" then
            if #str < 2048 then
                return ("'%s'"):format(str), 'string'
            end
            return ("'%s...'"):format(str:sub(1, 2048)), 'string'
        end
        if #str < 1024 then
            return ("'%s'"):format(quotedString(str)), 'string'
        end
        return ("'%s...'"):format(quotedString(str:sub(1, 1024))), 'string'
    elseif type == 'boolean' then
        if rdebug.value(value) then
            return 'true', 'boolean'
        else
            return 'false', 'boolean'
        end
    elseif type == 'nil' then
        return 'nil', 'nil'
    elseif type == 'integer' then
        return formatInteger(value), 'integer'
    elseif type == 'float' then
        return floatToString(rdebug.value(value)), 'float'
    elseif type == 'function' then
        return varGetFunctionCode(value), 'function'
    elseif type == 'c function' then
        return "C function", 'c function'
    elseif type == 'table' then
        if context == "clipboard" then
            return serialize(value), 'table'
        end
        return varGetTableValue(value), 'table'
    elseif type == 'userdata' then
        return varGetUserdata(value, allow_lazy)
    elseif type == 'lightuserdata' then
        return 'light'..tostring(rdebug.value(value)), 'lightuserdata'
    elseif type == 'thread' then
        return ('thread (%s)'):format(rdebug.costatus(value)), 'thread'
    elseif type == 'cdata' then
        local t = eval.ffi_reflect("shorttypename", value)
        if not t then
            return "cdata", 'cdata'
        end
        local v = eval.ffi_reflect("shortvalue", value)
        if not v then
            return t, 'cdata'
        end
        return tostring(v).." ("..t..")", 'cdata'
    elseif type == 'ctype' then
        local name = eval.ffi_reflect("shorttypename", value)
        return "ctype("..(name or "unknown")..")", 'ctype'
    end
    return tostring(rdebug.value(value)), type
end

local function varCreateReference(value, evaluateName, presentationHint, context)
    local valuestr, type, lazy = varGetValue(context, true, value)
    local result = {
        type = type,
        value = valuestr,
        presentationHint = presentationHint,
    }
    result.presentationHint.lazy = lazy
    if type == "integer" then
        result.__vscodeVariableMenuContext = showIntegerAsHex and "integer/hex" or "integer/dec"
    end
    if type == "string" or type == "userdata" then
        memoryRefPool[#memoryRefPool + 1] = {
            type = type,
            value = value,
        }
        result.memoryReference = #memoryRefPool
    end
    if varCanExtand(type, value) or result.presentationHint.lazy then
        varPool[#varPool + 1] = {
            v = value,
            eval = evaluateName,
            lazy = result.presentationHint.lazy,
            context = context,
        }
        result.variablesReference = #varPool
        if type == "table" then
            local asize, hsize = rdebug.tablesize(value)
            result.indexedVariables = arrayBase + asize
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
        local cache = globalCache[frameId]
        local scope = scopes[#scopes]
        local asize, hsize = rdebug.tablesize(cache.value)
        scope.indexedVariables = asize == 0 and 0 or (arrayBase + asize)
        scope.namedVariables = hsize
        local var = varPool[#varPool]
        var.v = cache.value
        var.eval = cache.eval
    end
end

local function varCreateTableKV(key, value, context)
    varPool[#varPool + 1] = {
        v = { key, value },
        special = "TableKV",
    }
    local valuestr, _, lazy = varGetValue(context, true, value)
    return {
        type = 'TableKV',
        value = valuestr,
        name = string.format("[%s]", rdebug.type(key)),
        variablesReference = #varPool,
        presentationHint = {
            kind = 'virtual',
            lazy = lazy,
        }
    }
end

local function varCreate(t)
    local vars = t.vars
    local name = t.name
    local extand = t.varRef.extand
    if extand[name] then
        local index = extand[name].index
        local nameidx = extand[name].nameidx
        local var = vars[index]
        if not nameidx or (var.presentationHint and var.presentationHint.kind == "virtual") then
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
        extand[newname].evaluateName = nil
        extand[name] = nil
    end
    if type(t.evaluateName) ~= "string" then
        t.evaluateName = nil
    end
    local var = varCreateReference(t.value, t.evaluateName, t.presentationHint or {}, "variables")
    var.name = name
    var.evaluateName = t.evaluateName
    vars[#vars + 1] = var
    extand[name] = {
        calcValue = t.calcValue,
        evaluateName = t.evaluateName,
        index = #vars,
        nameidx = t.nameidx,
        memoryReference = var.memoryReference,
    }
end

local function cfunctioninfo(func)
    local key = tostring(func)
    if cfunctionInfo[key] then
        return cfunctionInfo[key]
    end
    local info = rdebug.cfunctioninfo(func)
    cfunctionInfo[key] = info
    return info
end

local function getTabelKey(key)
    local type = rdebug.type(key)
    if type == 'string' then
        local str = rdebug.value(key)
        ---@cast str string
        if str:match '^[_%a][_%w]*$' then
            return ('.%s'):format(str)
        end
        return ('[%q]'):format(str)
    elseif type == 'boolean' or type == 'float' or type == 'integer' then
        return ('[%s]'):format(tostring(rdebug.value(key)))
    end
end

local function evaluateTabelKey(table, key)
    local evaluateKey = getTabelKey(key)
    if table and evaluateKey then
        return ("%s%s"):format(table, evaluateKey)
    end
end

local function extandTableIndexed(varRef, start, count)
    varRef.extand = varRef.extand or {}
    local t = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local last = start + count - 1
    if start < arrayBase then
        start = arrayBase
    end
    if last < start then
        return vars
    end
    local loct = rdebug.tablearray(t, start-arrayBase, last-arrayBase)
    for i = 1, #loct, 2 do
        local key = start + i // 2
        local value, valueref = loct[i], loct[i + 1]
        if value ~= nil then
            local name = (key < 1000) and ('[%03d]'):format(key) or ('%d'):format(key)
            varCreate {
                vars = vars,
                varRef = varRef,
                name = name,
                value = value,
                evaluateName = evaluateName and ('%s[%d]'):format(evaluateName, key),
                calcValue = function() return valueref end,
            }
        end
    end
    return vars
end

local function extandTableNamed(varRef)
    varRef.extand = varRef.extand or {}
    local t = varRef.v
    local evaluateName = varRef.eval
    local vars = {}
    local loct = rdebug.tablehash(t, 0, MAX_TABLE_HASH)
    for i = 1, #loct, 3 do
        local key, value, valueref = loct[i], loct[i + 1], loct[i + 2]
        local key_type = rdebug.type(key)
        if varCanExtand(key_type, key) then
            vars[#vars + 1] = varCreateTableKV(key, value, "variables")
        else
            varCreate {
                vars = vars,
                varRef = varRef,
                name = varGetName(key),
                value = value,
                evaluateName = evaluateTabelKey(evaluateName, key),
                calcValue = function() return valueref end,
            }
        end
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    local meta = rdebug.getmetatablev(t)
    if meta ~= nil then
        varCreate {
            vars = vars,
            varRef = varRef,
            name = '[metatable]',
            value = meta,
            evaluateName = evaluateName and ('debug.getmetatable(%s)'):format(evaluateName),
            calcValue = function() return rdebug.getmetatable(t) end,
            presentationHint = {
                kind = "virtual"
            }
        }
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
    else
        return extandTableNamed(varRef)
    end
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
        local displayName = isCFunction and ("[upvalue %d]"):format(i) or name
        local fi = i
        varCreate {
            vars = vars,
            varRef = varRef,
            name = displayName,
            value = value,
            evaluateName = evaluateName and ('select(2, debug.getupvalue(%s,%d))'):format(evaluateName, i),
            calcValue = function()
                local _, r = rdebug.getupvalue(f, fi)
                return r
            end,
            presentationHint = {
                kind = "virtual"
            }
        }
        i = i + 1
    end
    if isCFunction then
        local info = cfunctioninfo(f)
        local function createVar(name, value)
            vars[#vars+1] = {
                name = name,
                value = value,
                type = 'string',
                presentationHint = {
                    kind = "virtual",
                    attributes = "readOnly",
                }
            }
        end
        if info then
            for key, value in pairs(info) do
                createVar(key, value)
            end
        end
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
        varCreate {
            vars = vars,
            varRef = varRef,
            name = '[metatable]',
            value = meta,
            evaluateName = evaluateName and ('debug.getmetatable(%s)'):format(evaluateName),
            calcValue = function() return rdebug.getmetatable(u) end,
            presentationHint = {
                kind = "virtual"
            }
        }
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
                varCreate {
                    vars = vars,
                    varRef = varRef,
                    name = ('[uservalue %d]'):format(i),
                    value = uv,
                    evaluateName = evaluateName and ('debug.getuservalue(%s,%d)'):format(evaluateName, i),
                    calcValue = function() return rdebug.getuservalue(u, fi) end,
                    presentationHint = {
                        kind = "virtual"
                    }
                }
            end
            i = i + 1
        end
    else
        local uv = rdebug.getuservaluev(u)
        if uv ~= nil then
            varCreate {
                vars = vars,
                varRef = varRef,
                name = '[uservalue]',
                value = uv,
                evaluateName = evaluateName and ('debug.getuservalue(%s)'):format(evaluateName),
                calcValue = function() return rdebug.getuservalue(u) end,
                presentationHint = {
                    kind = "virtual"
                }
            }
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
    rdebug.getinfo(frameId, "u", info)
    if info.nparams > 0 then
        i = i + info.nparams
    end
    while true do
        local name, value = rdebug.getlocalv(frameId, i)
        if name == nil then
            break
        end
        if not isTemporary(name) then
            if name:sub(1, 1) == "(" then
                tempVar[name] = tempVar[name] and (tempVar[name] + 1) or 1
                name = ("(%s #%d)"):format(name:sub(2, -2), tempVar[name])
            end
            local fi = i
            varCreate {
                vars = vars,
                varRef = varRef,
                name = name,
                value = value,
                evaluateName = name,
                calcValue = function()
                    local _, r = rdebug.getlocal(frameId, fi)
                    return r
                end,
            }
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
    rdebug.getinfo(frameId, "f", info)
    local f = info.func
    while true do
        local name, value = rdebug.getupvaluev(f, i)
        if name == nil then
            break
        end
        local fi = i
        varCreate {
            vars = vars,
            varRef = varRef,
            name = name,
            value = value,
            evaluateName = name,
            calcValue = function()
                local _, r = rdebug.getupvalue(f, fi)
                return r
            end,
        }
        i = i + 1
    end
    return vars
end

function special_extand.Parameter(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local vars = {}

    rdebug.getinfo(frameId, "u", info)
    if info.nparams > 0 then
        for i = 1, info.nparams do
            local name, value = rdebug.getlocalv(frameId, i)
            if name ~= nil then
                local fi = i
                varCreate {
                    vars = vars,
                    varRef = varRef,
                    name = name,
                    nameidx = i,
                    value = value,
                    evaluateName = name,
                    calcValue = function()
                        local _, r = rdebug.getlocal(frameId, fi)
                        return r
                    end,
                }
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
        varCreate {
            vars = vars,
            varRef = varRef,
            name = ('[vararg %d]'):format(-i),
            value = value,
            evaluateName = ('select(%d,...)'):format(-i),
            calcValue = function()
                local _, r = rdebug.getlocal(frameId, fi)
                return r
            end,
        }
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
                varCreate {
                    vars = vars,
                    varRef = varRef,
                    name = ('[%d]'):format(i - info.ftransfer + 1),
                    value = value,
                    evaluateName = nil,
                    calcValue = function()
                        local _, r = rdebug.getlocal(frameId, fi)
                        return r
                    end,
                }
            end
        end
    end
    return vars
end

local function extandGlobalNamed(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local vars = {}
    local cache = globalCache[frameId]
    local loct = cache.global
    for i = 1, #loct, 3 do
        local key, value, valueref = loct[i], loct[i + 1], loct[i + 2]
        varCreate {
            vars = vars,
            varRef = varRef,
            name = varGetName(key),
            value = value,
            evaluateName = evaluateTabelKey(cache.eval, key),
            calcValue = function() return valueref end,
        }
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

function special_extand.Global(varRef, filter, start, count)
    if filter == 'indexed' then
        return extandTableIndexed(varRef, start, count)
    elseif filter == 'named' then
        return extandGlobalNamed(varRef)
    else
        return extandGlobalNamed(varRef)
    end
end

function special_extand.Standard(varRef)
    varRef.extand = varRef.extand or {}
    local frameId = varRef.frameId
    local vars = {}
    local cache = globalCache[frameId]
    local loct = cache.standard
    for i = 1, #loct, 3 do
        local key, value, valueref = loct[i], loct[i + 1], loct[i + 2]
        varCreate {
            vars = vars,
            varRef = varRef,
            name = varGetName(key),
            value = value,
            evaluateName = evaluateTabelKey(cache.eval, key),
            calcValue = function() return valueref end,
        }
    end
    table.sort(vars, function(a, b) return a.name < b.name end)
    return vars
end

function special_extand.TableKV(varRef)
    varRef.extand = varRef.extand or {}
    local key, value = table.unpack(varRef.v)
    local vars = {}
    varCreate({
        vars = vars,
        varRef = varRef,
        name = "key",
        value = key,
        calcValue = function() return key end,
    })
    varCreate({
        vars = vars,
        varRef = varRef,
        name = "value",
        value = value,
        calcValue = function() return value end,
    })
    return vars
end

local function VarCreateCData(varRef, vars, reflct, member, value)
    if rdebug.type(member) ~= 'nil' then
        local name = rdebug.fieldv(reflct, "name");
        varCreate({
            vars = vars,
            varRef = varRef,
            name = name,
            value = member,
            calcValue = function() return member end,
            presentationHint = {
                kind = "virtual",
                attributes = "readOnly",
            }
        })
    else
        local what = rdebug.fieldv(reflct, "what")
        varPool[#varPool + 1] = {
            v = { reflct, value },
            special = 'CData'
        }
        vars[#vars + 1] = {
            type = "string",
            name = "[anonymous]",
            value = what,
            presentationHint = {
                kind = "virtual",
                attributes = "readOnly",
            },
            variablesReference = #varPool
        }
    end
end

function special_extand.CData(varRef)
    varRef.extand = varRef.extand or {}
    local typeinfo, value = table.unpack(varRef.v)
    local vars = {}
    local index = 1
    while true do
        local reflct, member = eval.ffi_reflect("annotated_member", typeinfo, index, value)
        if not reflct then
            break
        end
        VarCreateCData(varRef, vars, reflct, member, value)
        index = index + 1
    end
    return vars
end

local function extandCData(varRef)
    varRef.extand = varRef.extand or {}
    local value = varRef.v
    local what = eval.ffi_reflect("what", value)
    local type = eval.ffi_reflect("typename", value)
    if not type then
        return {}
    end
    local vars = {}
    if what == "func" then
        vars[1] = {
            type = "string",
            name = "type",
            value = type or "unknown type",
            presentationHint = {
                kind = "virtual",
                attributes = "readOnly",
            }
        }
        vars[2] = {
            type = "integer",
            name = "value",
            value = eval.ffi_reflect("shortvalue", value),
            presentationHint = {
                kind = "virtual",
                attributes = "readOnly",
            }
        }
        local info = cfunctioninfo(value)
        if info then
            vars[3] = {
                type = "string",
                name = "[native]",
                value = (info.function_name or 'unknown')..":"..(info.line_number or '?'),
                presentationHint = {
                    kind = "virtual",
                    attributes = "readOnly",
                }
            }
        end
    else
        local index = 1
        while true do
            local reflct, member = eval.ffi_reflect("member", value, index)
            if not reflct then
                break
            end
            VarCreateCData(varRef, vars, reflct, member, value)
            index = index + 1
        end
    end

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
    elseif type == 'cdata' then
        return extandCData(varRef)
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
    elseif value:sub(1, 1) == "'" and value:sub(-1, -1) == "'" then
        newvalue = value:sub(2, -2)
    elseif value:sub(1, 1) == '"' and value:sub(-1, -1) == '"' then
        newvalue = value:sub(2, -2)
    elseif tonumber(value) then
        newvalue = tonumber(value)
    else
        newvalue = value
    end
    local extand = varRef.extand[name]
    local calcValue, evaluateName = extand.calcValue, extand.evaluateName
    local rvalue = calcValue()
    if not rdebug.assign(rvalue, newvalue) then
        return nil, 'Failed set variable'
    end
    if extand.memoryReference then
        local memoryRef = memoryRefPool[extand.memoryReference]
        if memoryRef then
            memoryRef.value = rvalue
            if memoryRef.range then
                local s, e = memoryRef.range[1], memoryRef.range[2]
                ev.emit('memory', extand.memoryReference, s, e - s)
            end
        end
    end
    return varCreateReference(rvalue, evaluateName, {}, "variables")
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
    local vars = extandValue(varRef, filter, start, count)
    if varRef.lazy then
        --TODO: fuck VSCode
        local valuestr, type = varGetValue(varRef.context, false, varRef.v)
        table.insert(vars, 1, {
            name = "",
            type = type,
            value = valuestr,
        })
    end
    return vars
end

function m.set(valueId, name, value)
    local varRef = varPool[valueId]
    if not varRef then
        return nil, 'Error variablesReference'
    end
    return setValue(varRef, name, value)
end

local function updateRange(ref, offset, count)
    local s, e = offset, offset + count
    if not ref.range then
        ref.range = { s, e }
        return
    end
    ref.range[1] = math.min(ref.range[1], s)
    ref.range[2] = math.max(ref.range[2], e)
end

function m.readMemory(memoryReference, offset, count)
    local memoryRef = memoryRefPool[memoryReference]
    if not memoryRef then
        return nil, 'Error memoryReference'
    end
    offset = offset or 0
    if memoryRef.type == "string" then
        local str = rdebug.value(memoryRef.value)
        ---@cast str string
        local slice = str:sub(offset + 1, offset + count)
        if not slice then
            return {
                address = tostring(offset),
                unreadableBytes = count,
            }
        end
        updateRange(memoryRef, offset, #slice)
        return {
            address = tostring(offset),
            unreadableBytes = count - #slice,
            data = base64.encode(slice),
        }
    elseif memoryRef.type == "userdata" then
        local slice = rdebug.udread(memoryRef.value, offset, count)
        if not slice then
            return {
                address = tostring(offset),
                unreadableBytes = count,
            }
        end
        updateRange(memoryRef, offset, #slice)
        return {
            address = tostring(offset),
            unreadableBytes = count - #slice,
            data = base64.encode(slice),
        }
    else
        return nil, "Unknown memory type"
    end
end

function m.writeMemory(memoryReference, offset, data, allowPartial)
    local memoryRef = memoryRefPool[memoryReference]
    if not memoryRef then
        return nil, 'Error memoryReference'
    end
    offset = offset or 0
    if memoryRef.type == "string" then
        return nil, "Readonly memory"
    elseif memoryRef.type == "userdata" then
        data = base64.decode(data)
        local res = rdebug.udwrite(memoryRef.value, offset, data, allowPartial)
        if not res then
            return nil, 'Write failed'
        end
        if allowPartial then
            return { bytesWritten = res }
        end
        return {}
    else
        return nil, "Unknown memory type"
    end
end

function m.clean()
    varPool = {}
    memoryRefPool = {}
    globalCache = {}
    cfunctionInfo = {}
    rdebug.cleanwatch()
end

function m.createText(value, context)
    return varGetValue(context, false, value)
end

function m.createRef(value, evaluateName, context)
    return varCreateReference(value, evaluateName, {}, context)
end

function m.tostring(v)
    local meta = rdebug.getmetatablev(v)
    if meta ~= nil then
        local fn = rdebug.fieldv(meta, '__tostring')
        if fn ~= nil then
            local ok, res = rdebug.eval(fn, v)
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

function m.showIntegerAsDec()
    showIntegerAsHex = false
end

function m.showIntegerAsHex()
    showIntegerAsHex = true
end

ev.on('terminated', function()
    m.clean()
end)

return m
