local ImGui     = require "imgui"
local uiconfig  = require "widget.config"
local utils     = require "common.utils"
local channel    = require "bee.channel"
local log_widget = require "widget.log"
local m = {}
local log_item_height = 22
local console_sender
function m.init_console_sender()
    if not console_sender then
        console_sender = channel.query "console_channel"
    end
end

local command_queue = {}
local history_pos = -1

local console = ImGui.StringBuf()

local function exec_command(command)
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
        message = "[" .. utils.time2str(os.time()) .. "][INFO][Console]" .. command,
        height = log_item_height,
        line_count = 1
    })
    if console_sender then
        console_sender:push(command)
    end
end

local faicons   = require "common.fa_icons"
local function show_input()
    ImGui.Text(faicons.ICON_FA_TERMINAL)
    ImGui.SameLine()
    local reclaim_focus = false
    ImGui.PushItemWidth(-1)
    --TODO
    --local flags = ImGui.InputTextFlags {"EnterReturnsTrue", "CallbackCompletion", "CallbackHistory"}
    if ImGui.InputText("##SingleLineInput", console, ImGui.InputTextFlags { "EnterReturnsTrue" }) then
        local command = tostring(console)
        if command ~= "" then
            exec_command(command)
            console:Assgin ""
        end
        reclaim_focus = true
    end
    ImGui.PopItemWidth()
    ImGui.SetItemDefaultFocus()
    if reclaim_focus then
        ImGui.SetKeyboardFocusHereEx(-1)
    end
    ImGui.Separator()
end

function m.get_title()
    return "Console"
end

function m.show()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x, viewport.WorkPos.y + viewport.WorkSize.y - uiconfig.BottomWidgetHeight, ImGui.Cond.FirstUseEver)
    ImGui.SetNextWindowSize(viewport.WorkSize.x, uiconfig.BottomWidgetHeight, ImGui.Cond.FirstUseEver)
    if ImGui.Begin("Console", nil, ImGui.WindowFlags { "NoCollapse", "NoScrollbar" }) then
        show_input()
        log_widget.showConsole()
    end
    ImGui.End()
end

return m