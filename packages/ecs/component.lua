local function init(w, c, component)
    local ti = assert(w._class.component[c], c)
    if ti.methodfunc and ti.methodfunc.init then
        return ti.methodfunc.init(component)
    end
    return component
end

local function delete(ti, component)
    if ti.methodfunc and ti.methodfunc.delete then
        ti.methodfunc.delete(component)
    end
end

local function solve(w)
    local typeinfo = w._class.component
    local schema = w._schema_data
    for _,v in ipairs(schema.list) do
        if v.uncomplete then
            error(v.name .. " is uncomplete")
        end
    end
    for k, parent in pairs(schema._undefined) do
        if typeinfo[parent] and not typeinfo[k] then
            error(k .. " is undefined in " .. parent)
        end
    end
end

return {
    init = init,
    delete = delete,
    solve = solve,
}
