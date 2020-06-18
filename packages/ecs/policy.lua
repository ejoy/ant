local function create(w, policies)
    local solve_depend = require "solve_depend"
    local res = {
        policy = policies,
        component = {},
        register_component = {},
        action = {},
        process_entity = {},
        process_prefab = {},
    }
    local unionset = {}
    local policyset = {}
    local transformset = {}
    local actionset = {}
    local reflection = {}
    local function table_append(t, a)
        table.move(a, 1, #a, #t+1, t)
    end
    local import_policy
    local import_transform
    function import_transform(name)
        if transformset[name] then
            return
        end
        transformset[name] = true
        local class = w._class.transform[name]
        for _, v in ipairs(class.policy) do
            import_policy(v)
        end
        for _, v in ipairs(class.transform) do
            import_transform(v)
        end
        for _, v in ipairs(class.input) do
            if not reflection[v] then
                reflection[v] = {depend={}}
            end
        end
        for _, v in ipairs(class.output) do
            if not reflection[v] then
                reflection[v] = {depend={}}
            end
            if reflection[v].name then
                error(("transform `%s` and transform `%s` has same output."):format(name, reflection[v].name))
            else
                reflection[v].name = name
            end
            if class.input then
                table_append(reflection[v].depend, class.input)
            end
        end
    end
    function import_policy(name)
        if policyset[name] then
            return
        end
        policyset[name] = true
        local class = w._class.policy[name]
        if not class then
            error(("policy `%s` is not defined."):format(name))
        end
        if class.union then
            if unionset[class.union] then
                error(("duplicate union `%s` in `%s` and `%s`."):format(class.union, name, unionset[class.union]))
            end
            unionset[class.union] = name
        end
        for _, v in ipairs(class.policy) do
            import_policy(v)
        end
        for _, v in ipairs(class.transform) do
            import_transform(v)
        end
        for _, v in ipairs(class.component) do
            if not res.register_component[v] then
                res.register_component[v] = true
                res.component[#res.component+1] = v
            end
        end
        for _, v in ipairs(class.action) do
            if not actionset[v] then
                actionset[v] = true
                res.action[#res.action+1] = v
            end
        end
    end
    for _, name in ipairs(policies) do
        import_policy(name)
    end
    local mark = {}
    for _, c in ipairs(solve_depend(reflection)) do
        local name = reflection[c].name
        if name and not mark[name] then
            mark[name] = true
            local class = w._class.transform[name]
            if class.process_prefab then
                res.process_prefab[#res.process_prefab+1] = class.process_prefab
                for _, v in ipairs(class.output) do
                    res.register_component[v] = true
                end
            end
            if class.process_entity then
                res.process_entity[#res.process_entity+1] = class.process_entity
                for _, v in ipairs(class.output) do
                    res.register_component[v] = true
                end
            end
        end
    end

    table.sort(res.component)
    table.sort(res.action)
    return res
end

local function add(w, eid, policies)
    local res = create(w, policies)
    if #res.action > 0 then
        error "action can only be imported during instance."
    end
    local e = w[eid]
    for _, policy_name in ipairs(policies) do
        local class = w._class.policy[policy_name]
        for _, transform_name in ipairs(class.transform) do
            local class = w._class.transform[transform_name]
            for _, v in ipairs(class.output) do
                if e[v] ~= nil then
                    error(("component `%s` already exists, it conflicts with policy `%s`."):format(v, policy_name))
                end
            end
        end
    end
    local i = 1
    while i <= #res.component do
        local c = res.component[i]
        if e[c] ~= nil then
            table.remove(res.component, i)
        else
            i = i + 1
        end
    end
    return res
end

return {
    create = create,
    add = add,
}
