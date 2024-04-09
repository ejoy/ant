local serialize = import_package "ant.serialize"

local component_desc = serialize.load "/pkg/tools.editor/common/component_desc.txt"
local component_names = {}
for k in pairs(component_desc) do
    component_names[#component_names+1] = k
end
table.sort(component_names)

local function sort_pairs(t)
    local s = {}
    for k in pairs(t) do
        s[#s+1] = k
    end

    table.sort(s)

    local n = 1
    return function ()
        local k = s[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

return {
    desc = component_desc,
    names = component_names,
    sort_pairs = sort_pairs,
}