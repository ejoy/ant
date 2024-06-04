local function component_def(w, c)
    local component_decl = w._decl.component[c] or error(string.format("unknown component `%s`", c))
    local component_type = component_decl.type[1]
    if component_type == nil then
        return true
    elseif component_type == "lua" then
        return false
    elseif component_type == "c" then
        return false
    elseif component_type == "raw" then
        return ("\0"):rep(assert(math.tointeger(w._decl.component[c].size[1])))
    else
        return 0
    end
end

local allow <const> = {
    on_ready = true,
}

local function verify(w, policies, data, symbol)
    assert(type(policies) == "table")
    local component = {}
    local component_opt = {}
    local policyset = {}
    local function import_policy(name)
        if policyset[name] then
            return
        end
        policyset[name] = true
        local decl = w._decl.policy[name]
        if not decl then
            error(("policy `%s` is not defined."):format(name))
        end
        for _, v in ipairs(decl.include_policy) do
            import_policy(v)
        end
        for _, v in ipairs(decl.component) do
            component[v] = true
        end
        for _, v in ipairs(decl.component_opt) do
            component_opt[v] = true
        end
    end
    for _, name in ipairs(policies) do
        import_policy(name)
    end
    for c in pairs(component_opt) do
        if data[c] == nil then
            data[c] = component_def(w, c)
        end
    end
    for c in pairs(component) do
        if data[c] == nil then
            error(("component `%s` must exists"):format(c))
        end
    end
    for c in pairs(data) do
        if component[c] == nil and component_opt[c] == nil and allow[c] == nil then
            local decl = w._decl.component[c]
            if decl and decl.type[1] ~= nil then
                error(("`%s` component `%s` is not included in the policy"):format(symbol, c))
            end
        end
    end
end

return {
    verify = verify,
}
