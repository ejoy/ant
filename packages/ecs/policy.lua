local typeclass = require "typeclass"

local function create(w, policies)
    local policy_class = w._class.policy
    local transform_class = w._class.transform
    local solve_depend = require "solve_depend"
    local transform = {}
    local component = {}
    local init_component = {}
    local connection = {}
    local init_connection = {}
    local policyset = {}
    local unionset = {}
    for _, name in ipairs(policies) do
        local class = policy_class[name]
        if not class then
            typeclass.import_object(w, "policy", name)
            class = policy_class[name]
            if not class then
                error(("policy `%s` is not defined."):format(name))
            end
        end
        if policyset[name] then
            goto continue
        end
        policyset[name] = name
        if class.union then
            if unionset[class.union] then
                error(("duplicate union `%s` in `%s` and `%s`."):format(class.union, name, unionset[class.union]))
            end
            unionset[class.union] = name
        end
        for _, v in ipairs(class.require_transform) do
            if not transform[v] then
                transform[v] = {}
            end
        end
        for _, v in ipairs(class.component) do
            if not component[v] then
                component[v] = {depend={}}
                init_component[#init_component+1] = v
            end
        end
        for _, v in ipairs(class.unique_component) do
            if not component[v] then
                component[v] = {depend={}}
                init_component[#init_component+1] = v
            end
        end
        for _, v in ipairs(class.connection) do
            if not connection[v] then
                connection[v] = true
                init_connection[#init_connection+1] = v
            end
        end
        ::continue::
    end
    local function table_append(t, a)
        table.move(a, 1, #a, #t+1, t)
    end
    local reflection = {}
    for name in pairs(transform) do
        local class = transform_class[name]
        for _, v in ipairs(class.output) do
            if not component[v] then
                component[v] = {depend={}}
                init_component[#init_component+1] = v
            end
            if reflection[v] then
                error(("transform `%s` and transform `%s` has same output."):format(name, reflection[v]))
            end
            reflection[v] = name
            if class.input then
                if not component[v] then
                    component[v] = {depend={}}
                end
                table_append(component[v].depend, class.input)
            end
        end
    end
    local mark = {}
    local init_transform = {}
    for _, c in ipairs(solve_depend(component)) do
        local name = reflection[c]
        if name and not mark[name] then
            mark[name] = true
            init_transform[#init_transform+1] = transform_class[name].methodfunc.process
        end
    end
    table.sort(init_component)
    table.sort(init_connection)
    return init_component, init_transform, init_connection
end

local function add(w, eid, policies)
    local component, transform = create(w, policies)
    local e = w[eid]
    local policy_class = w._class.policy
    local transform_class = w._class.transform
    for _, policy_name in ipairs(policies) do
        local class = policy_class[policy_name]
        for _, transform_name in ipairs(class.require_transform) do
            local class = transform_class[transform_name]
            for _, v in ipairs(class.output) do
                if e[v] ~= nil then
                    error(("component `%s` already exists, it conflicts with policy `%s`."):format(v, policy_name))
                end
            end
        end
    end
    local i = 1
    while i <= #component do
        local c = component[i]
        if e[c] ~= nil then
            table.remove(component, i)
        else
            i = i + 1
        end
    end
    return component, transform
end

return {
    create = create,
    add = add,
}
