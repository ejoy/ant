local imgui     = require "imgui"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local world

local m = {}

local LEVEL_INFO = 0x0000001
local LEVEL_WARN = 0x0000002
local LEVEL_ERROR = 0x0000004

local filter_flag = LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR
local log_item_height = 22

local level_color = {
    info = {62/255,154/255,73/255,0.8},
    warn = {229/255,241/255,33/255,0.8},
    error = {255/255,0,0,0.8}
}

local log_items = {
    [LEVEL_INFO] = {},
    [LEVEL_WARN] = {},
    [LEVEL_ERROR] = {},
    [LEVEL_INFO | LEVEL_WARN] = {},
    [LEVEL_INFO | LEVEL_ERROR] = {},
    [LEVEL_WARN | LEVEL_ERROR] = {},
    [LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR] = {}
}

local function time2str( time )
    local fmt = "%Y-%m-%d %H:%M:%S:"
    local ti, tf = math.modf(time)
    return os.date(fmt, ti)..string.format("%03d",math.floor(tf*1000))
end

function m.info(msg)
    local vit = {level = LEVEL_INFO, message = "[INFO][" .. time2str(os.time()) .. "]" .. msg}
    table.insert(log_items[LEVEL_INFO], vit)
    table.insert(log_items[LEVEL_INFO | LEVEL_WARN], vit)
    table.insert(log_items[LEVEL_INFO | LEVEL_ERROR], vit)
    table.insert(log_items[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], vit)
end

function m.warn(msg)
    local vit = {level = LEVEL_WARN, message = "[WARN][" .. time2str(os.time()) .. "]" .. msg}
    table.insert(log_items[LEVEL_WARN], vit)
    table.insert(log_items[LEVEL_WARN | LEVEL_INFO], vit)
    table.insert(log_items[LEVEL_WARN | LEVEL_ERROR], vit)
    table.insert(log_items[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], vit)
end

function m.error(msg)
    local vit = {level = LEVEL_ERROR, message = "[ERROR][" .. time2str(os.time()) .. "]" .. msg}
    table.insert(log_items[LEVEL_ERROR], vit)
    table.insert(log_items[LEVEL_ERROR | LEVEL_INFO], vit)
    table.insert(log_items[LEVEL_ERROR | LEVEL_WARN], vit)
    table.insert(log_items[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], vit)
end

local function get_active_count()
    local count = 0
    if filter_flag | LEVEL_INFO then
        count = count + #log_items[LEVEL_INFO]
    end
    if filter_flag | LEVEL_WARN then
        count = count + #log_items[LEVEL_WARN]
    end
    if filter_flag | LEVEL_ERROR then
        count = count + #log_items[LEVEL_ERROR]
    end
    return count
end

local show_info = {true}
local show_warn = {true}
local show_error = {true}
local current_select = -1
function m.show(rhwi)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - uiconfig.LogWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, uiconfig.LogWidgetHeight, 'F')
    
    if #log_items[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR] == 0 then
        for i = 1, 5000, 3 do
            m.info("helloworld_" .. i)
            m.warn("helloworld_" .. i + 1)
            m.error("helloworld_" .. i + 2)
        end
    end

    for _ in uiutils.imgui_windows("Log", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if imgui.widget.Button("Clear") then

        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("Info", show_info) then
            if show_info[1] then
                filter_flag = filter_flag | LEVEL_INFO
            else
                filter_flag = filter_flag & (~LEVEL_INFO)
            end
        end
        imgui.cursor.SameLine()
        imgui.widget.Text(tostring(#log_items[LEVEL_INFO]))

        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("Warn", show_warn) then
            if show_warn[1] then
                filter_flag = filter_flag | LEVEL_WARN
            else
                filter_flag = filter_flag & (~LEVEL_WARN)
            end
        end
        imgui.cursor.SameLine()
        imgui.widget.Text(tostring(#log_items[LEVEL_WARN]))

        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("Error", show_error) then
            if show_error[1] then
                filter_flag = filter_flag | LEVEL_ERROR
            else
                filter_flag = filter_flag & (~LEVEL_ERROR)
            end
        end
        imgui.cursor.SameLine()
        imgui.widget.Text(tostring(#log_items[LEVEL_ERROR]))

        local total_filter_count = (filter_flag > 0) and #log_items[filter_flag] or 0
        if total_filter_count > 0 then
            imgui.cursor.Separator()
            local winWidth, winHeight = imgui.windows.GetWindowSize()
            imgui.windows.SetNextWindowContentSize(0, get_active_count() * log_item_height)
            imgui.windows.BeginChild("LogDetail", 0, 0, false, imgui.flags.Window { "HorizontalScrollbar" })
            local scrolly = imgui.windows.GetScrollY()
            local aw, ah = imgui.windows.GetWindowSize()
            local item_count = math.ceil(ah / log_item_height)
            local start_idx = math.floor(scrolly / log_item_height)
            imgui.cursor.SetCursorPos(nil, start_idx * log_item_height)
            start_idx = start_idx + 1
            local max_idx = total_filter_count - item_count + 1
            if start_idx > max_idx then
                start_idx = max_idx
            end
            local end_idx = start_idx + item_count + 1
            if end_idx > total_filter_count then
                end_idx = total_filter_count
            end
            for i = start_idx, end_idx do
                local color
                item = log_items[filter_flag][i]
                if item.level == LEVEL_WARN then
                    color = level_color.warn
                elseif item.level == LEVEL_ERROR then
                    color = level_color.error
                end
                if color then
                    imgui.windows.PushStyleColor(imgui.enum.StyleCol.Text, color[1], color[2], color[3], color[4])
                end
                if imgui.widget.Selectable(item.message, current_select == i) then
                    current_select = i
                end
                if color then
                    imgui.windows.PopStyleColor()
                end
            end
            imgui.windows.EndChild()
        end
    end
end

return function(w)
    world = w
    return m
end