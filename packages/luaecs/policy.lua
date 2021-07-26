local function create(w, policies)
    local res = {
        component = {},
        unique_component = {},
    }
    local componentset = {}
    local unionset = {}
    local policyset = {}
    local function import_policy(name)
        if policyset[name] then
            return
        end
        policyset[name] = true
        local class = w._class.policy_v2[name]
        if not class then
            error(("policy `%s` is not defined."):format(name))
        end
        if class.union then
            if unionset[class.union] then
                error(("duplicate union `%s` in `%s` and `%s`."):format(class.union, name, unionset[class.union]))
            end
            unionset[class.union] = name
        end
        for _, v in ipairs(class.policy_v2) do
            import_policy(v)
        end
        for _, v in ipairs(class.component_v2) do
            if not componentset[v] then
                componentset[v] = true
                res.component[#res.component+1] = v
            end
        end
    end
    for _, name in ipairs(policies) do
        import_policy(name)
    end

    table.sort(res.component)

    for _, c in ipairs(res.component) do
        if w._class.unique[c] then
            res.unique_component[#res.unique_component+1] = c
        end
    end

    return res
end

return {
    create = create,
}
