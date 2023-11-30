local datalist = require "datalist"
local fs = require "filesystem"
local fastio = require "fastio"

local component_desc = datalist.parse(fastio.readall_f(fs.path "/pkg/tools.editor/common/component_desc.txt":localpath():string(), "/pkg/tools.editor/common/component_desc.txt"))
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