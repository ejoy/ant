local rmlui = require "rmlui"

local m = {}

local function setVariable(datamodel, element, name, value)
    local vars = datamodel.variables[element]
    if not vars then
        vars = {}
        datamodel.variables[element] = vars
    end
    vars[name] = value
end

function m.create(datamodel, view, element, value)
    local var_it, var_index, var_t = value:match "^%s*([%w_%.]+),%s*([%w_%.]+)%s*:%s*([%w_%.]+)%s*$"
    if var_t then
        view.var_it = var_it
        view.var_index = var_index
        view.var_t = var_t
    else
        var_it, var_t = value:match "^%s*([%w_%.]+)%s*:%s*([%w_%.]+)%s*$"
        if var_t then
            view.var_it = var_it
            view.var_index = "it_index"
            view.var_t = var_t
        else
            var_t = value:match "^%s*([%w_%.]+)%s*$"
            if var_t then
                view.var_it = "it"
                view.var_index = "it_index"
                view.var_t = var_t
            else
                error(("invalid data-for: `%s`"):format(value))
            end
        end
    end
    view.script = view.variables.."\nreturn "..var_t
end

function m.refresh(datamodel, element, view)
    local compiled, err = load(view.script, view.script, "t", datamodel.model)
    if not compiled then
        log.warn(err)
        return
    end
    local t = compiled()
    local parent = rmlui.NodeGetParent(element)
    local dirty = false
    for i = view.num_elements+1, #t do
        local sibling = rmlui.NodeClone(element)
        setVariable(datamodel, sibling, view.var_it,    ("%s[%d]"):format(view.var_t, i))
        setVariable(datamodel, sibling, view.var_index, ("%d"):format(i))
        rmlui.ElementInsertBefore(parent, sibling, element)
        dirty = true
    end
    for i = #t+1, view.num_elements do
        local sibling = rmlui.ElementGetPreviousSibling(element)
        rmlui.ElementRemoveChild(parent, sibling)
        dirty = true
    end
    if dirty then
        view.num_elements = #t
        datamodel.dirty = true
    end
end

return m
