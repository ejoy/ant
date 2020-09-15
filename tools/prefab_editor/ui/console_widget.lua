local imgui     = require "imgui"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local cthread   = require "thread"
local log_widget
local m = {}
local log_item_height = 22
local console_sender
function m.init_console_sender()
    if not console_sender then
        console_sender = cthread.channel_produce "console_channel"
    end
end

local command_queue = {}
local history_pos = -1
local console = {
    text = "",
    flags = imgui.flags.InputText{"EnterReturnsTrue", "CallbackCompletion", "CallbackHistory"},
    up = function()
            if #command_queue < 1 then return "" end

            local prev_history_pos = history_pos
            if history_pos == -1 then
                history_pos = #command_queue - 1
            elseif history_pos > 0 then
                history_pos = history_pos - 1
            end
            if prev_history_pos ~= history_pos then
                return (history_pos >= 0) and command_queue[history_pos + 1] or ""
            else
                return nil
            end
        end,
    down = function()
            if #command_queue < 1 then return "" end

            local prev_history_pos = history_pos
            if history_pos ~= -1 then
                history_pos = history_pos + 1
                if history_pos >= #command_queue then
                    history_pos = -1
                end
            end
            if prev_history_pos ~= history_pos then
                return (history_pos >= 0) and command_queue[history_pos + 1] or ""
            else
                return nil
            end
        end
}

local function execCommand(command)
    history_pos = -1
    local exist_idx = 0
    for i, v in ipairs(command_queue) do
        if v == command then
            exist_idx = i
            break
        end
    end
    if exist_idx ~= 0 then
        table.remove(command_queue, exist_idx)
    end
    table.insert(command_queue, command)
    log_widget.info({
        tag = "Console",
        message = "[" .. uiutils.time2str(os.time()) .. "][INFO][Console]" .. command,
        height = log_item_height,
        line_count = 1
    })
    if console_sender then
        console_sender:push(command)
    end
end

local function showInput()
    imgui.widget.Text(">")
    imgui.cursor.SameLine()
    local reclaim_focus = false
    imgui.cursor.PushItemWidth(-1)
    if imgui.widget.InputText("##SingleLineInput", console) then
        local command = tostring(console.text)
        if command ~= "" then
            execCommand(command)
            console.text = ""
        end
        reclaim_focus = true
    end
    imgui.cursor.PopItemWidth()
    imgui.util.SetItemDefaultFocus()
    if reclaim_focus then
        imgui.util.SetKeyboardFocusHere(-1)
    end
    imgui.cursor.Separator()
end
function m.show(rhwi)
    --log_widget.checkLog()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - uiconfig.ConsoleWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, uiconfig.ConsoleWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Console", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        showInput()
        log_widget.showConsole()
    end
end

return function(am)
    log_widget = require "ui.log_widget"(am)
    return m
end