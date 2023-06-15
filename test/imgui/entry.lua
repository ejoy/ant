local imgui = require "imgui"
local bgfx = require "bgfx"

local MyItemColumnID_ID       <const> = 0
local MyItemColumnID_Name     <const> = 1
local MyItemColumnID_Action   <const> = 2
local MyItemColumnID_Quantity <const> = 3

local template_items_names = {
    "Banana", "Apple", "Cherry", "Watermelon", "Grapefruit", "Strawberry", "Mango",
    "Kiwi", "Orange", "Pineapple", "Blueberry", "Plum", "Coconut", "Pear", "Apricot"
}

local items = {}
for n = 1, 50 do
    items[#items+1] = {
        ID = n,
        Quantity = (n * n - n) % 20,
        Name = template_items_names[1 + (n % #template_items_names)],
    }
end

local clipper = imgui.table.Clipper()
local sortspecs = {}

local function sortItems(a, b)
    local delta = 0
    for i = 1, sortspecs.n do
        local spec = sortspecs[i]
        if spec.ColumnUserID == MyItemColumnID_ID then
            delta = a.ID - b.ID
        elseif spec.ColumnUserID == MyItemColumnID_Name then
            if a.Name > b.Name then
                delta = 1
            elseif a.Name < b.Name then
                delta = -1
            else
                delta = 0
            end
        elseif spec.ColumnUserID == MyItemColumnID_Quantity then
            delta = a.Quantity - b.Quantity
        else
            assert(false)
        end
        if delta > 0 then
            return spec.SortDirection ~= imgui.enum.SortDirection.Ascending
        end
        if delta < 0 then
            return spec.SortDirection == imgui.enum.SortDirection.Ascending
        end
    end
    return a.ID < b.ID
end

local test_cb = {true}

local function init()
    local platform    = require "bee.platform"
    local Font        = imgui.font.SystemFont
    local function glyphRanges(t)
        assert(#t % 2 == 0)
        local s = {}
        for i = 1, #t do
            s[#s+1] = ("<I4"):pack(t[i])
        end
        s[#s+1] = "\x00\x00\x00"
        return table.concat(s)
    end
    if platform.os == "windows" then
        imgui.font.Create {
            { Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
            { Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
        }
    elseif platform.os == "macos" then
        imgui.font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    elseif platform.os == "ios" then
        imgui.font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    else
        error("unknown os:" .. platform.os)
    end
end

local function update(viewid)
    bgfx.set_view_clear(viewid, "CD", 0x303030ff, 1, 0)

    if imgui.windows.Begin ("test", imgui.flags.Window {'AlwaysAutoResize'}) then
        if imgui.table.Begin("split", 4, imgui.flags.Table {
            'Resizable','Reorderable','Hideable','Sortable',
            'RowBg','BordersOuter','BordersV','NoBordersInBody', 'ScrollY'
        }, 0, 400) then
            imgui.table.SetupColumn("ID", imgui.flags.TableColumn {'DefaultSort', 'WidthFixed'}, -1.0, MyItemColumnID_ID)
            imgui.table.SetupColumn("Name", imgui.flags.TableColumn {'WidthFixed'}, -1.0, MyItemColumnID_Name)
            imgui.table.SetupColumn("Action", imgui.flags.TableColumn {'NoSort', 'WidthFixed'},   -1.0, MyItemColumnID_Action)
            imgui.table.SetupColumn("Quantity", imgui.flags.TableColumn {'PreferSortDescending', 'WidthStretch'}, -1.0, MyItemColumnID_Quantity)
            imgui.table.SetupScrollFreeze(0, 1)
            imgui.table.HeadersRow()

            if imgui.table.GetSortSpecs(sortspecs) then
                table.sort(items, sortItems)
            end

            for display_start, display_end in clipper(#items) do
                for i = display_start, display_end do
                    local item = items[i]
                    imgui.util.PushID(item.ID)
                    imgui.table.NextRow()
                    imgui.table.NextColumn()
                    imgui.widget.Text(("%04d"):format(item.ID))
                    imgui.table.NextColumn()
                    imgui.widget.Text(item.Name)
                    imgui.table.NextColumn()
                    imgui.widget.SmallButton("None")
                    imgui.table.NextColumn()
                    imgui.widget.Text(("%d"):format(item.Quantity))
                    imgui.util.PopID()
                end
            end
            imgui.table.End()
        end
        imgui.windows.End()
    end

    if imgui.windows.Begin ("test1", imgui.flags.Window {'AlwaysAutoResize'}) then
        imgui.widget.Checkbox("##abc1", test_cb)
        imgui.cursor.SameLine()

        imgui.windows.BeginDisabled(not test_cb[1])
        imgui.widget.InputFloat("bb", {1.0})
        imgui.windows.EndDisabled()
        -- do  --checkbox test
        --     if test_cb == nil then
        --         test_cb = {false}
        --     end
        --     if test_cb[1] then
        --         imgui.widget.Text "abababa"
        --     else
        --         imgui.widget.TextDisabled "abababa"
        --     end
        --      imgui.cursor.SameLine() imgui.widget.Checkbox("enable", test_cb)
        -- end

        imgui.windows.BeginDisabled(true)
        if imgui.widget.TreeNode("Test", imgui.flags.TreeNode{"DefaultOpen"}) then
            imgui.windows.BeginDisabled(true)
            local t = {text = "i m input text"}
            if imgui.widget.InputText("abc5", t) then
                print(tostring(t.text))
            end
            imgui.windows.EndDisabled()
            imgui.widget.TreePop()
        end
        imgui.windows.EndDisabled()
        imgui.windows.End()
    end
end

return {
    init = init,
    update = update,
}
