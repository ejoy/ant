local rdebug = require 'remotedebug.visitor'
local variables = require 'backend.worker.variables'
local luaver = require 'backend.worker.luaver'

local readfile = package.readfile
if not readfile then
    function readfile(filename)
        local fullpath = assert(package.searchpath(filename, package.path))
        local f = assert(io.open(fullpath))
        local str = f:read 'a'
        f:close()
        return str
    end
end

local eval_repl   = assert(rdebug.reffunc(readfile 'backend.worker.eval_repl'))
local eval_watch  = assert(rdebug.reffunc(readfile 'backend.worker.eval_watch'))
local eval_verify = assert(rdebug.reffunc(readfile 'backend.worker.eval_verify'))
local eval_dump   = assert(rdebug.reffunc(readfile 'backend.worker.eval_dump'))
local compat_dump = assert(load(readfile 'backend.worker.eval_dump'))

local function run_repl(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_repl, 'return ' .. expression, frameId))
    if not res[1] then
        local ok = rdebug.evalwatch(eval_repl, expression, frameId)
        if not ok then
            return false, res[2]
        end
        return true, { value = '' }
    end
    if res.n == 1 then
        return true, { value = 'nil' }
    end
    local var = variables.createRef(res[2], expression, "repl")
    res[2] = var.value
    for i = 3, res.n do
        res[i] = variables.createText(res[i], "repl")
    end
    var.value = table.concat(res, ',', 2)
    return true, var
end

local function run_hover(frameId, expression)
    local ok, res = rdebug.evalwatch(eval_watch, expression, frameId)
    if not ok then
        return false, res
    end
    return true, variables.createRef(res, expression, "hover")
end

local function run_watch(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_watch, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    if res.n == 1 then
        return true, { value = 'nil' }
    end
    local var = variables.createRef(res[2], expression, "watch")
    res[2] = var.value
    for i = 3, res.n do
        res[i] = variables.createText(res[i], "watch")
    end
    var.value = table.concat(res, ',', 2)
    return true, var
end

local function run_copyvalue(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_watch, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    if res.n == 1 then
        return true, { value = 'nil' }
    end
    for i = 2, res.n do
        res[i] = variables.createText(res[i], "copyvalue")
    end
    return true, { value = table.concat(res, ',', 2) }
end

local m = {}

function m.run(frameId, expression, context)
    if context == "watch" then
        return run_watch(frameId, expression)
    end
    if context == "hover" then
        return run_hover(frameId, expression)
    end
    if context == "repl" then
        return run_repl(frameId, expression)
    end
    if context == nil then
        return run_copyvalue(frameId, expression)
    end
    return nil, ("unknown context `%s`"):format(context)
end

function m.eval(expression, level)
    return rdebug.eval(eval_watch, expression, level or 0)
end

function m.verify(expression)
    return rdebug.eval(eval_verify, expression, 0)
end

function m.dump(content)
    if luaver.LUAVERSION <= 52 then
        local res, err = compat_dump(content)
        if res then
            return true, res
        end
        return false, err
    end
    return rdebug.eval(eval_dump, content, 0)
end

return m
