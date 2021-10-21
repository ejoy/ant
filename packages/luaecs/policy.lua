local function create(w, package, policies)
    local res = {
        component = {},
        component_opt = {},
    }
    local componentset = {}
    local unionset = {}
    local policyset = {}
    local function import_policy(name)
        if policyset[name] then
            return
        end
        policyset[name] = true
        local class = w:_import("policy", package, name)
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
        for _, v in ipairs(class.component) do
            if not componentset[v] then
                componentset[v] = true
                res.component[#res.component+1] = v
            end
        end
        for _, v in ipairs(class.component_opt) do
            if res.component_opt[v] == nil then
                local component_class = w._decl.component
                local component_type =  component_class[v].type[1]
                if component_type == nil then
                    res.component_opt[v] = true
                elseif component_type == "lua" then
                    res.component_opt[v] = false
                else
                    res.component_opt[v] = 0
                end
            end
        end
    end
    for _, name in ipairs(policies) do
        import_policy(name)
    end
    return res
end

return {
    create = create,
}
