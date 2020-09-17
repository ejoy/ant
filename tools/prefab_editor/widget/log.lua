local imgui     = require "imgui"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local utils     = require "common.utils"
local cthread = require "thread"

local icons
local m = {
    to_bottom = false
}

local log_tags = {
    "All",
    "Engine",
    "Editor",
    "Network",
    "Thread",
    "FileSrv",
    "FileWatch",
    "Runtime",
    "Server",
    "Console"
}

local LEVEL_INFO = 0x0000001
local LEVEL_WARN = 0x0000002
local LEVEL_ERROR = 0x0000004
local filter_flag = LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR
local log_item_height = 22
local current_tag = "All"
local show_info = {true}
local show_warn = {true}
local show_error = {true}
local current_select = -1
local level_color = {
    info = {62/255,154/255,73/255,0.8},
    warn = {229/255,241/255,33/255,0.8},
    error = {255/255,0,0,0.8}
}

local log_items = {}

local function get_log_height()
    local height = 0
    if filter_flag | LEVEL_INFO then
        height = height + log_items[current_tag][LEVEL_INFO].height
    end
    if filter_flag | LEVEL_WARN then
        height = height + log_items[current_tag][LEVEL_WARN].height
    end
    if filter_flag | LEVEL_ERROR then
        height = height + log_items[current_tag][LEVEL_ERROR].height
    end
    return height
end

local function do_add(t, item)
    table.insert(t, item)
    t.height = t.height + item.height
    for i = 1, item.line_count do
        t.vtor_index[#t.vtor_index + 1] = {#t, i - 1}
    end
end

local function do_add_info(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container[LEVEL_INFO], item)
    do_add(container[LEVEL_INFO | LEVEL_WARN], item)
    do_add(container[LEVEL_INFO | LEVEL_ERROR], item)
    do_add(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
end
local function do_add_warn(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container[LEVEL_WARN], item)
    do_add(container[LEVEL_WARN | LEVEL_INFO], item)
    do_add(container[LEVEL_WARN | LEVEL_ERROR], item)
    do_add(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
end
local function do_add_error(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container[LEVEL_ERROR], item)
    do_add(container[LEVEL_ERROR | LEVEL_INFO], item)
    do_add(container[LEVEL_ERROR | LEVEL_WARN], item)
    do_add(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
end

function m.message(msg)
    if msg.level == LEVEL_INFO then
        m.info(msg)
    elseif msg.level == LEVEL_WARN then
        m.warn(msg)
    elseif msg.level == LEVEL_ERROR then
        m.error(msg)
    end
end

function m.info(msg)
    msg.level = LEVEL_INFO
    do_add_info("All", msg)
    do_add_info(msg.tag, msg)
    m.to_bottom = true
end

function m.warn(msg)
    msg.level = LEVEL_WARN
    do_add_warn("All", msg)
    do_add_warn(msg.tag, msg)
    m.to_bottom = true
end

function m.error(msg)
    msg.level = LEVEL_ERROR
    do_add_error("All", msg)
    do_add_error(msg.tag, msg)
    m.to_bottom = true
end


local err_receiver
local function reset_log()
    for i, v in ipairs(log_tags) do
        log_items[v] = {
            [LEVEL_INFO] = {height = 0, vtor_index = {}},
            [LEVEL_WARN] = {height = 0, vtor_index = {}},
            [LEVEL_ERROR] = {height = 0, vtor_index = {}},
            [LEVEL_INFO | LEVEL_WARN] = {height = 0, vtor_index = {}},
            [LEVEL_INFO | LEVEL_ERROR] = {height = 0, vtor_index = {}},
            [LEVEL_WARN | LEVEL_ERROR] = {height = 0, vtor_index = {}},
            [LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR] = {height = 0, vtor_index = {}}
        }
    end
end

local log_receiver
function m.init_log_receiver()
    if not log_receiver then
        log_receiver = cthread.channel_consume "log_channel"
    end
end

local function checkLog()
    local error, info = err_receiver:pop()
    if error then
        local count = 1
        for _ in string.gmatch(info, '\n') do
            count = count + 1
        end
        m.error({
            tag = "Thread",
            message = "[" .. utils.time2str(os.time()) .. "][Thread]" .. info,
            height = count * log_item_height,
            line_count = count
        })
    end

    if not log_receiver then return end

    local has, msg = log_receiver:pop()
    while has do
        local level = "info"
        local msg_tag = "All"
        local msg_str = ""
        local type = msg[1]
        if type == "CONSOLE" then
            msg_tag = "Console"
            msg_str = "[" .. utils.time2str(os.time()) .. "][" .. level:upper() .. "][" .. msg_tag .."]"
            for i = 2, #msg do
                msg_str = msg_str .. msg[i]
            end
        elseif type == "RUNTIME" then
            msg_tag = "Runtime"
            msg_str = msg[2]
            local first = string.find(msg_str, "]")
            if first then
                local rawlevel = string.sub(msg_str, first + 2, string.find(msg_str, "]", first + 1) - 1)
                level = string.lower(rawlevel:match'^%s*(.*%S)' or '')
            end
        elseif type == "SERVER" then
            level = msg[3]
            msg_tag = msg[4]--"Server"
            msg_str = "[" .. utils.time2str(msg[2]) .. "][" .. level:upper() .. "][".. msg_tag .. "]"
            for i = 5, #msg do
                if i > 5 then
                    msg_str = msg_str .. "    "
                end
                msg_str = msg_str .. msg[i]
            end
        end
        local count = 1
        for _ in string.gmatch(msg_str, '\n') do
            count = count + 1
        end
        local item = {
            tag = msg_tag,
            message = msg_str,
            height = count * log_item_height,
            line_count = count
        }
        if level == "warn" then
            m.warn(item)
        elseif level == "error" then
            m.error(item)
        --elseif level == "info" then
        else
            m.info(item)
        end
        has, msg = log_receiver:pop()
    end
end

local function showHeaderWidget(logbytag)
    if imgui.widget.Button("Clear") then
        reset_log()
    end
    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Info(" .. tostring(#logbytag[LEVEL_INFO]) .. ")", show_info) then
        if show_info[1] then
            filter_flag = filter_flag | LEVEL_INFO
        else
            filter_flag = filter_flag & (~LEVEL_INFO)
        end
    end

    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Warn(" .. tostring(#logbytag[LEVEL_WARN]) .. ")", show_warn) then
        if show_warn[1] then
            filter_flag = filter_flag | LEVEL_WARN
        else
            filter_flag = filter_flag & (~LEVEL_WARN)
        end
    end

    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Error(" .. tostring(#logbytag[LEVEL_ERROR]) .. ")", show_error) then
        if show_error[1] then
            filter_flag = filter_flag | LEVEL_ERROR
        else
            filter_flag = filter_flag & (~LEVEL_ERROR)
        end
    end

    imgui.cursor.SameLine()
    imgui.widget.Text("Show:")
    imgui.cursor.SameLine()
    imgui.cursor.SetNextItemWidth(120)
    if imgui.widget.BeginCombo("##Show", {current_tag}) then
        for i, tag in ipairs(log_tags) do
            if imgui.widget.Selectable(tag, current_tag == tag) then
                current_tag = tag
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.cursor.Separator()
end

function m.showLog(name, current_log)
    local total_virtual_count = #current_log
    if total_virtual_count <= 0 then return end
    imgui.windows.SetNextWindowContentSize(0, current_log.height)
    imgui.windows.BeginChild(name, 0, 0, false, imgui.flags.Window { "HorizontalScrollbar" })
    if m.to_bottom then
        imgui.windows.SetScrollY(imgui.windows.GetScrollMaxY())
        m.to_bottom = false
    end
    local scrolly = imgui.windows.GetScrollY()
    local aw, ah = imgui.windows.GetWindowContentRegionMax()
    local item_count = math.ceil(ah / log_item_height)
    local items_to_show = scrolly / log_item_height
    local v_start_idx = math.floor(items_to_show) + 1
    local max_idx = 1
    if total_virtual_count > item_count then
        max_idx = total_virtual_count - item_count + 1
    end
    if v_start_idx > max_idx then
        v_start_idx = max_idx
    end
    local v_end_idx = v_start_idx + item_count + 1
    if v_end_idx > total_virtual_count then
        v_end_idx = total_virtual_count
    end
    local _, remain = math.modf(items_to_show)
    local offset = remain + current_log.vtor_index[v_start_idx][2]
    if offset < 0 then
        offset = 0
    end
    imgui.cursor.SetCursorPos(nil, scrolly - offset * log_item_height)
    local start_idx = current_log.vtor_index[v_start_idx][1]
    local end_idx = current_log.vtor_index[v_end_idx][1]
    for i = start_idx, end_idx do
        local color
        item = current_log[i]
        if item.level == LEVEL_INFO then
            imgui.widget.Image(icons.ICON_INFO.handle, icons.ICON_INFO.texinfo.width, icons.ICON_INFO.texinfo.height)
        elseif item.level == LEVEL_WARN then
            imgui.widget.Image(icons.ICON_WARN.handle, icons.ICON_WARN.texinfo.width, icons.ICON_WARN.texinfo.height)
            color = level_color.warn
        elseif item.level == LEVEL_ERROR then
            imgui.widget.Image(icons.ICON_ERROR.handle, icons.ICON_ERROR.texinfo.width, icons.ICON_ERROR.texinfo.height)
            color = level_color.error
        end
        imgui.cursor.SameLine()
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

function m.showConsole()
    m.showLog("ConsoleList", log_items["Console"][LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR])
end

function m.show(rhwi)
    if not err_receiver then
        err_receiver = cthread.channel_consume "errlog"
    end
    checkLog()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - uiconfig.LogWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, uiconfig.LogWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Log", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        showHeaderWidget(log_items[current_tag])
        m.showLog("LogList", log_items[current_tag][filter_flag])
    end
end

return function(am)
    icons = require "common.icons"(am)
    reset_log()
    return m
end