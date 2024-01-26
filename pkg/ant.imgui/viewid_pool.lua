local rhwi = import_package "ant.hwi"

local pool = {}

for i = 1, 20 do
    pool[i] = rhwi.viewid_generate("imgui_" .. i, "uiruntime")
end

return pool
