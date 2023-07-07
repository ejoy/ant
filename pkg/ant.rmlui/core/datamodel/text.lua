local rmlui = require "rmlui"
local console = require "core.sandbox.console"

local m = {}

local function eval(data)
    return data.script:gsub('{%d+}', function(key)
        local code = data.code[key]
        if not code then
            return key
        end
        return code()
    end)
end

local function refresh(data, node)
    local res = eval(data)
    rmlui.TextSetText(node, res)
end

function m.load(datamodel, data, node, value)
    local n = 0
    data.code = {}
    data.script = value:gsub('{{.*}}', function(str)
        n = n + 1
        local key = ('{%d}'):format(n)
        local script = data.variables.."\nreturn "..str:sub(3, -3)
        local compiled, err = load(script, script, "t", datamodel.model)
        if not compiled then
            console.warn(err)
            return str
        end
        data.code[key] = compiled
        return key
    end)
    refresh(data, node)
end

function m.refresh(datamodel)
    for node, data in pairs(datamodel.texts) do
        refresh(data, node)
    end
end

return m
