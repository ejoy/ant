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

local eval_readwrite = assert(rdebug.load(readfile 'backend.worker.eval.readwrite'))
local eval_readonly  = assert(rdebug.load(readfile 'backend.worker.eval.readonly'))
local eval_verify    = assert(rdebug.load(readfile 'backend.worker.eval.verify'))
local eval_dump      = assert(rdebug.load(readfile 'backend.worker.eval.dump'))
local compat_dump    = assert(load(readfile 'backend.worker.eval.dump'))

local function run_repl(frameId, expression)
    local res = table.pack(rdebug.watch(eval_readwrite, 'return ' .. expression, frameId))
    if not res[1] then
        res = table.pack(rdebug.watch(eval_readwrite, expression, frameId))
        if not res[1] then
            return false, res[2]
        end
    end
    local var = variables.createRef(res[2], expression, "repl")
    local result = {var.value}
    for i = 3, res.n do
        result[i-1] = variables.createText(res[i], "repl")
    end
    var.result = table.concat(result, ',')
    var.value = nil
    return true, var
end

local function run_watch(frameId, expression)
    local res = table.pack(rdebug.watch(eval_readonly, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    local var = variables.createRef(res[2], expression, "watch")
    local result = {var.value}
    for i = 3, res.n do
        result[i-1] = variables.createText(res[i], "watch")
    end
    var.result = table.concat(result, ',')
    var.value = nil
    return true, var
end

local function run_hover(frameId, expression)
    local ok, res = rdebug.watch(eval_readonly, expression, frameId)
    if not ok then
        return false, res
    end
    local var = variables.createRef(res, "hover")
    var.result = var.value
    var.value = nil
    return true, var
end

local function run_clipboard(frameId, expression)
    local res = table.pack(rdebug.watch(eval_readonly, expression, frameId))
    if not res[1] then
        return false, res[2]
    end
    if res.n == 1 then
        return true, { result = 'nil' }
    end
    local result = {}
    for i = 2, res.n do
        result[i-1] = variables.createText(res[i], "clipboard")
    end
    return true, { result = table.concat(result, ',') }
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
    if context == "clipboard" then
        return run_clipboard(frameId, expression)
    end
    --兼容旧版本VSCode
    if context == "variables" then
        return run_clipboard(frameId, expression)
    end
    return nil, ("unknown context `%s`"):format(context)
end

function m.set(frameId, expression, value)
    local ok, res = rdebug.watch(eval_readwrite, expression.."="..value, frameId)
    if not ok then
        return false, res
    end
    return run_watch(frameId, expression)
end

function m.eval(expression, level, symbol)
    return rdebug.eval(eval_readonly, expression, level, symbol)
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
