local ImGui         = import_package "ant.imgui"
local global_data   = require "common.global_data"
local datalist      = require "datalist"
local serialize     = import_package "ant.serialize"

local ps = {
    id      = "ProjectSetting"
}

local function read_file(p)
    local f <close> = assert(io.open(p))
    return f:read "a"
end

local default_tr_flags = ImGui.Flags.TreeNode{}
local default_win_flags= ImGui.Flags.Window{}
local default_tab_flags= ImGui.Flags.TabBar{"Reorderable", "AutoSelectNewTabs"}

local TreeNode      = ImGui.TreeNode
local TreePop       = ImGui.TreePop
local PropertyLabel = ImGui.PropertyLabel
local Checkbox      = ImGui.Checkbox
local BeginCombo    = ImGui.BeginCombo
local EndCombo      = ImGui.EndCombo
local Button        = ImGui.Button
local BeginDisabled = ImGui.BeginDisabled
local EndDisabled   = ImGui.EndDisabled
local BeginTabBar   = ImGui.BeginTabBar
local EndTabBar     = ImGui.EndTabBar
local BeginTabItem  = ImGui.BeginTabItem
local EndTabItem    = ImGui.EndTabItem
local IsPopupOpen   = ImGui.IsPopupOpen
local BeginPopupModal=ImGui.BeginPopupModal
local EndPopup      = ImGui.EndPopup
local SameLine      = ImGui.SameLine

local function Property(name, value, ctrltype, config)
    PropertyLabel(name)
    SameLine()
    return ImGui[ctrltype]("##"..name, value, config)
end

local function PropertyFloat(name, value, config)
    return Property(name, value, "DragFloat", config)
end

local function PropertyColor(name, value, config)
    return Property(name, value, "ColorEdit", config)
end

local function CheckProperty(name, value, enable, p, set_p, config)
    local _, result = Checkbox("##"..name, enable)
    SameLine()
    BeginDisabled(not result)
    
    if p(name, value, config) then
        set_p(value)
    end
    EndDisabled()

    return result
end

local function toRGBColor(dwColor)
    local r = dwColor & 0xff
    local g = (dwColor >> 8) & 0xff
    local b = (dwColor >> 16) & 0xff
    local a = (dwColor >> 24) & 0xff
    return {r/255.0, g/255.0, b/255.0, a/255.0}
end

local function toDWColor(rgbcolor)
    local r = math.floor(rgbcolor[1] * 255)
    local g = math.floor(rgbcolor[2] * 255)
    local b = math.floor(rgbcolor[3] * 255)
    local a = math.floor(rgbcolor[4] * 255)

    return r|g<<8|b<<16|a<<24
end

local default_curve_world<const> = {
    enable = false,
    type = "cylinder",
    flat_distance = 0,
    curve_rate = 0.05,
    distance = 500,
    type_options = {"cylinder", "view_sphere"}
}

local project_settings = {}

local function deep_copy(dst)
    local src = {}
    for k, v in pairs(default_curve_world) do
        if type(v) == "table" then
            src[k] = deep_copy(v)
        else
            src[k] = v
        end
    end
    return src
end

local function setting_ui(sc)
    local graphic = sc.graphic

    if TreeNode("Graphic", default_tr_flags) then
        --Render
        if TreeNode("Render", ImGui.Flags.TreeNode{}) then
            local r = graphic.render
            if TreeNode("Clear State", ImGui.Flags.TreeNode{}) then

                local rs = {}
                local rbgcolor = toRGBColor(r.clear_color)
                if CheckProperty("Color", rbgcolor, r.clear:match "C"~=nil, PropertyColor, function (rgbcolor)
                    --sc:set("graphic/render/clear_color", toDWColor(rgbcolor))
                    r.clear_color = toDWColor(rgbcolor)
                end) then
                    rs[#rs+1] = "C"
                end

                local v = {r.clear_depth}
                if CheckProperty("Depth", v, r.clear:match "D"~=nil, PropertyFloat, function (v)
                    --sc:set("graphic/render/clear_depth", v[1])
                    r.clear_depth = v[1]
                end) then
                    rs[#rs+1] = "D"
                end


                v[1] = r.clear_stencil
                if CheckProperty("Stencil", v, r.clear:match "S"~=nil, PropertyFloat, function (v)
                    --sc:set("graphic/render/clear_stencil", v[1])
                    r.clear_stencil = v[1]
                end) then
                    rs[#rs+1] = "S"
                end

                if #rs >= 0 then
                    --sc:set("graphic/render/clear" ,table.concat(rs, ""))
                    r.clear = table.concat(rs, "")
                end
                TreePop()
            end

            TreePop()
        end

        --shadow
        if TreeNode("Shadow", default_tr_flags) then
            TreePop()
        end

        --postprocess
        if TreeNode("Postprocess", default_tr_flags) then
            local pp = graphic.postprocess
            if TreeNode("Bloom", default_tr_flags) then
                local b = pp.bloom
                local change, enable = Checkbox("Enable", b.enable)
                if change then
                    --sc:set("graphic/postprocess/bloom/enable", enable)
                    b.enable = enable
                end
                BeginDisabled(not enable)
                local v = {b.inv_highlight or 0.0}
                v.min, v.max = -64, 64
                v.speed = 0.2
                if PropertyFloat("Inverse HighLight", v) then
                    --sc:set("graphic/postprocess/bloom/inv_highlight", v[1])
                    b.inv_highlight = v[1]
                end

                v[1] = b.threshold or 0.0
                v.min, v.max = 0.0, 512
                if PropertyFloat("Lumnimance Thresthod", v) then
                    --sc:set("graphic/postprocess/bloom/threshold", v[1])
                    b.threshold = v[1]
                end
                EndDisabled()
                TreePop()
            end
            TreePop()
        end

        --curve world
        if TreeNode("Curve World", default_tr_flags)then
            local cw = graphic.curve_world

            SameLine()

            local modified
            local change, enable = Checkbox("Enable", cw and cw.enable or false)
            if change then
                if cw == nil then
                    --sc:set("graphic/curve_world", default_curve_world)
                    cw = deep_copy(default_curve_world)
                    graphic.curve_world = cw
                end
                sc:set("graphic/curve_world/enable", enable)
                modified = true
            end
            cw = cw or deep_copy(default_curve_world)

            BeginDisabled(not enable)
            if BeginCombo("Type", {cw.type, flags = ImGui.Flags.Combo{} }) then
                for _, n in ipairs(default_curve_world.type_options) do
                    if ImGui.Selectable(n, cw.type == n) then
                        --sc:set("graphic/curve_world/type", n)
                        cw.type = n
                        modified = true
                    end
                end
                EndCombo()
            end

            local t = cw.type
            if t == "cylinder" then
                local v = {cw.flat_distance, speed=1.0, min=0.0}
                if PropertyFloat("Flat Distance", v) then
                    --sc:set("graphic/curve_world/flat_distance", v[1])
                    cw.flat_distance = v[1]
                    modified = true
                end
                v[1] = cw.curve_rate
                v.speed = 0.01
                v.max = 1.0
                if PropertyFloat("Curve Rate", v) then
                    --sc:set("graphic/curve_world/curve_rate", v[1])
                    cw.curve_rate = v[1]
                    modified = true
                end

                v[1] = cw.distance
                v.speed = 0.5
                v.max = nil
                if PropertyFloat("Curve Distance", v) then
                    --sc:set("graphic/curve_world/distance", v[1])
                    cw.distance = v[1]
                    modified = true
                end
            else
                assert(cw.type == "view_sphere")
                --log.info("curve world type 'view_sphere' is not used")
            end
            EndDisabled()

            TreePop()
        end

        TreePop()
    end

    if Button "Save" then
        local p = global_data.project_root / "settings"
        local f <close> = assert(io.open(p:string(), "w"))
        f:write(serialize.stringify(sc))
    end
end

function ps.show(open_popup)
    if open_popup then
        ImGui.OpenPopup(ps.id)
        ImGui.SetNextWindowSize(800, 600)
    end

    if BeginPopupModal(ps.id, nil, default_win_flags) then
        if BeginTabBar("PS_Bar", default_tab_flags) then
            if BeginTabItem "ProjectSetting" then
                if global_data.project_root then
                    local p = global_data.project_root / "settings"
                    -- local p = "/pkg/ant.settings/default/graphic_settings.ant"
                    local s = project_settings[p]
                    if s == nil then
                        s = datalist.parse(read_file(p))
                        project_settings[p] = s
                    end
                    setting_ui(s)
                end
                EndTabItem()
            end
            EndTabBar()
        end

        EndPopup()
    end
end

return ps