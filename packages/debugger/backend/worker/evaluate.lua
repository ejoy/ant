local rdebug = require 'remotedebug.visitor'
local variables = require 'backend.worker.variables'

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

local eval_repl  = assert(rdebug.reffunc(readfile 'backend.worker.eval_repl'))
local eval_watch = assert(rdebug.reffunc(readfile 'backend.worker.eval_watch'))

local function run_repl(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_repl, 'return ' .. expression, frameId))
    if not res[1] then
        local ok = rdebug.evalwatch(eval_repl, expression, frameId)
        if not ok then
            return false, res[2]
        end
        return true, ''
    end
    if #res == 1 then
        return true, 'nil'
    end
    local _, ref
    res[2], _, ref = variables.createRef(frameId, res[2], expression)
    for i = 3, res.n do
        res[i] = variables.createText(res[i])
    end
    return true, table.concat(res, ',', 2), ref
end

local function run_hover(frameId, expression)
    local ok, res = rdebug.evalwatch(eval_watch, expression, frameId)
    if not ok then
        return false, res
    end
    local res, _, ref = variables.createRef(frameId, res, expression)
    return true, res, ref
end

local function run_watch(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_watch, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    if #res == 0 then
        return true, 'nil'
    end
    local _, ref
    res[2], _, ref = variables.createRef(frameId, res[2], expression)
    for i = 3, res.n do
        res[i] = variables.createText(res[i])
    end
    return true, table.concat(res, ',', 2), ref
end

local function run_copyvalue(frameId, expression)
    local res = table.pack(rdebug.evalwatch(eval_watch, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    if #res == 0 then
        return true, 'nil'
    end
    for i = 2, res.n do
        res[i] = variables.createText(res[i])
    end
    return true, table.concat(res, ',', 2)
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

function m.eval(expression)
    return rdebug.eval(eval_watch, expression, 0)
end

return m
