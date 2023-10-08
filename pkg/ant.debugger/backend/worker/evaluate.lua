local variables = require 'backend.worker.variables'
local eval = require 'backend.worker.eval'

local function run_repl(frameId, expression)
    local res = table.pack(eval.readwrite('return ' .. expression, frameId))
    if not res[1] then
        res = table.pack(eval.readwrite(expression, frameId))
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
    local res = table.pack(eval.readonly(expression, frameId))
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
    local ok, res = eval.readonly(expression, frameId)
    if not ok then
        return false, res
    end
    local var = variables.createRef(res, "hover")
    var.result = var.value
    var.value = nil
    return true, var
end

local function run_clipboard(frameId, expression)
    local res = table.pack(eval.readonly(expression, frameId))
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
    local ok, res = eval.readwrite(expression.."="..value..";return "..expression, frameId)
    if not ok then
        return false, res
    end
    local var = variables.createRef(res, expression, "variables")
    return true, var
end

return m
