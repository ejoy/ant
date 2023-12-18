local imgui = require "imgui"
local bgfx = require "bgfx"

local text = {text = ""}

local function update(viewid)
    bgfx.set_view_clear(viewid, "CD", 0x303030ff, 1, 0)

    if imgui.windows.Begin ("test", imgui.flags.Window {'AlwaysAutoResize'}) then
        if imgui.widget.TreeNode("Test", imgui.flags.TreeNode{"DefaultOpen"}) then
            if imgui.widget.InputText("TEST", text) then
                print(tostring(text.text))
            end
        end
        imgui.widget.TreePop()
    end
    imgui.windows.End()
end

return {
    update = update,
}
