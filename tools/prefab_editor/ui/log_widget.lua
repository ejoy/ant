local imgui     = require "imgui"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"

local fileserver_thread

local icons
local m = {}

local log_tags = {
    "All",
    "Engine",
    "Editor",
    "Network",
    "FileSrv",
    "FileWatch"
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

local function time2str( time )
    local fmt = "%Y-%m-%d %H:%M:%S:"
    local ti, tf = math.modf(time)
    return os.date(fmt, ti)..string.format("%03d",math.floor(tf*1000))
end

local function get_active_count()
    local count = 0
    if filter_flag | LEVEL_INFO then
        count = count + #log_items[current_tag][LEVEL_INFO]
    end
    if filter_flag | LEVEL_WARN then
        count = count + #log_items[current_tag][LEVEL_WARN]
    end
    if filter_flag | LEVEL_ERROR then
        count = count + #log_items[current_tag][LEVEL_ERROR]
    end
    return count
end

local function do_add_info(tag, item)
    local container = log_items[tag]
    if not container then return end
    table.insert(container[LEVEL_INFO], item)
    table.insert(container[LEVEL_INFO | LEVEL_WARN], item)
    table.insert(container[LEVEL_INFO | LEVEL_ERROR], item)
    table.insert(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
end
local function do_add_warn(tag, item)
    local container = log_items[tag]
    if not container then return end
    table.insert(container[LEVEL_WARN], item)
    table.insert(container[LEVEL_WARN | LEVEL_INFO], item)
    table.insert(container[LEVEL_WARN | LEVEL_ERROR], item)
    table.insert(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
end
local function do_add_error(tag, item)
    local container = log_items[tag]
    if not container then return end
    table.insert(container[LEVEL_ERROR], item)
    table.insert(container[LEVEL_ERROR | LEVEL_INFO], item)
    table.insert(container[LEVEL_ERROR | LEVEL_WARN], item)
    table.insert(container[LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR], item)
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
local new_log = false
function m.info(msg)
    local msg_str = {level = LEVEL_INFO, message = "[" .. time2str(msg.time) .. "][".. msg.tag .. "]" .. msg.content}
    do_add_info("All", msg_str)
    do_add_info(msg.tag, msg_str)
    new_log = true
end

function m.warn(msg)
    local msg_str = {level = LEVEL_WARN, message = "[" .. time2str(msg.time) .. "][".. msg.tag .. "]" .. msg.content}
    do_add_warn("All", msg_str)
    do_add_warn(msg.tag, msg_str)
    new_log = true
end

function m.error(msg)
    local msg_str = {level = LEVEL_ERROR, message = "[" .. time2str(msg.time) .. "][".. msg.tag .. "]" .. msg.content}
    do_add_error("All", msg_str)
    do_add_error(msg.tag, msg_str)
    new_log = true
end
local fileserver_ip = {text="0.0.0.0"}
local fileserver_port = {text="2018"}

local log_receiver

function m.show(rhwi)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - uiconfig.LogWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, uiconfig.LogWidgetHeight, 'F')
    local has, msg = log_receiver:pop()
    while has do
        local item = {time = msg[2], tag = msg[3], content = msg[4]}
        if msg[1] == "info" then
            m.info(item)
        elseif msg[1] == "warn" then
            m.warn(item)
        elseif msg[1] == "error" then
            m.error(item)
        end
        has, msg = log_receiver:pop()
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
        imgui.widget.Text(tostring(#log_items[current_tag][LEVEL_INFO]))

        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("Warn", show_warn) then
            if show_warn[1] then
                filter_flag = filter_flag | LEVEL_WARN
            else
                filter_flag = filter_flag & (~LEVEL_WARN)
            end
        end
        imgui.cursor.SameLine()
        imgui.widget.Text(tostring(#log_items[current_tag][LEVEL_WARN]))

        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("Error", show_error) then
            if show_error[1] then
                filter_flag = filter_flag | LEVEL_ERROR
            else
                filter_flag = filter_flag & (~LEVEL_ERROR)
            end
        end
        imgui.cursor.SameLine()
        imgui.widget.Text(tostring(#log_items[current_tag][LEVEL_ERROR]))

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

        -- imgui.cursor.SameLine()
        -- imgui.widget.Text("IP:")
        -- imgui.cursor.SameLine()
        -- imgui.cursor.SetNextItemWidth(150)
        
        -- if imgui.widget.InputText("##IP", fileserver_ip) then
        
        -- end
        
        -- imgui.cursor.SameLine()
        -- imgui.widget.Text("Port:")
        -- imgui.cursor.SameLine()
        -- imgui.cursor.SetNextItemWidth(60)
        
        -- if imgui.widget.InputText("##Port", fileserver_port) then
        
        -- end

        -- imgui.cursor.SameLine()
        -- if imgui.widget.Button("Connect") then

        -- end

        local total_filter_count = (filter_flag > 0) and #log_items[current_tag][filter_flag] or 0
        if total_filter_count > 0 then
            imgui.cursor.Separator()
            imgui.windows.SetNextWindowContentSize(0, get_active_count() * log_item_height)
            
            imgui.windows.BeginChild("LogDetail", 0, 0, false, imgui.flags.Window { "HorizontalScrollbar" })
            if new_log then
                new_log = false
                imgui.windows.SetScrollY(imgui.windows.GetScrollMaxY())
            end
            local scrolly = imgui.windows.GetScrollY()
            local aw, ah = imgui.windows.GetWindowSize()
            local item_count = math.ceil(ah / log_item_height)
            local start_idx = math.floor(scrolly / log_item_height)
            imgui.cursor.SetCursorPos(nil, start_idx * log_item_height)
            start_idx = start_idx + 1
            local max_idx = 1
            if total_filter_count > item_count then
                max_idx = total_filter_count - item_count + 1
            end
            if start_idx > max_idx then
                start_idx = max_idx
            end
            local end_idx = start_idx + item_count + 1
            if end_idx > total_filter_count then
                end_idx = total_filter_count
            end
            local current_log = log_items[current_tag][filter_flag]
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
    end
end

return function(am)
    icons = require "common.icons"(am)
    for i, v in ipairs(log_tags) do
        log_items[v] = {
            [LEVEL_INFO] = {},
            [LEVEL_WARN] = {},
            [LEVEL_ERROR] = {},
            [LEVEL_INFO | LEVEL_WARN] = {},
            [LEVEL_INFO | LEVEL_ERROR] = {},
            [LEVEL_WARN | LEVEL_ERROR] = {},
            [LEVEL_INFO | LEVEL_WARN | LEVEL_ERROR] = {}
        }
    end
    --test
    for i = 1, 500, 3 do
        m.info({time = os.time(), tag = log_tags[math.random(2, 4)], content = "helloworld_" .. i})
        m.warn({time = os.time(), tag = log_tags[math.random(2, 4)], content = "helloworld_" .. i + 1})
        m.error({time = os.time(), tag = log_tags[math.random(2, 4)], content = "helloworld_" .. i + 2})
    end
    --
    local cthread = require "thread"
    cthread.newchannel "log_channel"
    log_receiver = cthread.channel_consume "log_channel"
    local produce = cthread.channel_produce "log_channel"
    produce:push(arg)
    -- fileserver_thread = thread.thread(([[
    --     package.path = "engine/?.lua;packages/server/?.lua;tools/prefab_editor/?.lua"
    --     package.cpath = %q
    --     local fileserver = require "fileserver_adapter"()
    --     fileserver.run()
    -- ]]):format(package.cpath))
    
    local lthread = require "common.thread"
    fileserver_thread = lthread.create [[
        package.path = "engine/?.lua;tools/prefab_editor/?.lua"
        require "bootstrap"
        local fileserver = require "fileserver_adapter"()
        fileserver.run()
    ]]

	local thread = require "thread"
	local err = thread.channel_consume "errlog"
    --print("ERROR:" .. err())
    --thread.wait(fileserver_thread)
    return m
end