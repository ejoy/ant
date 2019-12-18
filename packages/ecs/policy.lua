local function apply(w, policies, dataset)
    local policy_class = w._class.policy
    local transform_class = w._class.transform
    local solve_depend = require "solve_depend"
    local transform = {}
    local component = {}
    local init_component = {}
    local policyset = {}
    local unionset = {}
    for _, name in ipairs(policies) do
        local class = policy_class[name]
        if not class then
            error(("policy `%s` is not defined."):format(name))
        end
        if policyset[name] then
            error(("duplicate policy `%s`."):format(name))
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
        for _, v in ipairs(class.require_component) do
            if not component[v] then
                component[v] = {depend={}}
                init_component[#init_component+1] = v
            end
        end
    end
    local function table_append(t, a)
        table.move(a, 1, #a, #t+1, t)
    end
    local reflection = {}
    for name in pairs(transform) do
        local class = transform_class[name]
        for _, v in ipairs(class.output) do
            if reflection[v] then
                error(("transform `%s` and transform `%s` has same output."):format(name, reflection[v]))
            end
            reflection[v] = name
            table_append(component[v].depend, class.input)
        end
    end
    local mark = {}
    local init_transform = {}
    for _, c in ipairs(solve_depend(component)) do
        local name = reflection[c]
        if name and not mark[name] then
            mark[name] = true
            init_transform[#init_transform+1] = transform_class[name].method.process
        end
    end

    if dataset then
        for name in pairs(dataset) do
            if not component[name] then
                error(("dataset have an unknown component `%s`."):format(name))
            end
        end
        local i = 1
        while true do
            local name = init_component[i]
            if not name then
                break
            end
            if not dataset[name] then
                if not reflection[name] then
                    error(("dataset does not have component `%s`."):format(name))
                end
                init_component[i] = init_component[#init_component]
                init_component[#init_component] = nil
            else
                i = i + 1
            end
        end
    end

    table.sort(init_component)
    return {
        init_component,
        init_transform,
    }
end

return {
    apply = apply,
}
