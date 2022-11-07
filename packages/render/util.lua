local function DEF_FUNC() end
local function def_sys(s, m, ...)
    if m then
        s[m] = DEF_FUNC
        def_sys(s, ...)
    end
end

return {
    default_system = def_sys,
}