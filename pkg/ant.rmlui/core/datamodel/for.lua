local rmlui = require "rmlui"
local console = require "core.sandbox.console"

local m = {}

local function eval(datamodel, script)
    local compiled, err = load(script, script, "t", datamodel.data_table)
    if not compiled then
        console.warn(err)
        return
    end
    return compiled()
end

local function setVariable(datamodel, element, name, value)
    local vars = datamodel.variables[element]
    if not vars then
        vars = {}
        datamodel.variables[element] = vars
    end
    vars[name] = value
end

local function refresh(datamodel, data, element)
    local parent = rmlui.NodeGetParent(element)
    local t = eval(datamodel, data.script)
    local dirty = false
    for i = data.num_elements+1, #t do
        local sibling = rmlui.NodeClone(element)
        setVariable(datamodel, sibling, data.var_it,    ("%s[%d]"):format(data.var_t, i))
        setVariable(datamodel, sibling, data.var_index, ("%d"):format(i))
        rmlui.ElementInsertBefore(parent, sibling, element)
        dirty = true
    end
    for i = #t+1, data.num_elements do
        local sibling = rmlui.ElementGetPreviousSibling(element)
        rmlui.ElementRemoveChild(parent, sibling)
        dirty = true
    end
    if dirty then
        data.num_elements = #t
        datamodel.model()
    end
end

function m.load(datamodel, view, element, value)
    local data = view["for"]
    local var_it, var_index, var_t = value:match "^%s*([%w_]+),%s*([%w_]+)%s*:%s*([%w_]+)%s*$"
    if var_t then
        data.var_it = var_it
        data.var_index = var_index
        data.var_t = var_t
    else
        var_it, var_t = value:match "^%s*([%w_]+):%s*([%w_]+)%s*$"
        if var_t then
            data.var_it = var_it
            data.var_index = "it_index"
            data.var_t = var_t
        else
            var_t = value:match "^%s*([%w_]+)%s*$"
            if var_t then
                data.var_it = "it"
                data.var_index = "it_index"
                data.var_t = var_t
            else
                error(("invaild data-for: `%s`"):format(value))
            end
        end
    end
    rmlui.ElementRemoveAttribute(element, "data-for")
    data.script = view.variables.."\nreturn "..var_t
    --refresh(datamodel, data, element)
end

function m.refresh(datamodel, element, view)
    local data = view["for"]
    if not data.script then
        return
    end
    refresh(datamodel, data, element)
end

return m
