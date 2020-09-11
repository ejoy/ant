local imgui     = require "imgui"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local cthread = require "thread"

local icons
local m = {}

local log_tags = {
    "All",
    "Engine",
    "Editor",
    "Network",
    "Thread",
    "FileSrv",
    "FileWatch"
}
-- 'trace'
-- 'debug'
-- 'info'
-- 'warn'
-- 'error'
-- 'fatal'
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
local new_log = false
function m.info(msg)
    msg.level = LEVEL_INFO
    do_add_info("All", msg)
    do_add_info(msg.tag, msg)
    new_log = true
end

function m.warn(msg)
    msg.level = LEVEL_WARN
    do_add_warn("All", msg)
    do_add_warn(msg.tag, msg)
    new_log = true
end

function m.error(msg)
    msg.level = LEVEL_ERROR
    do_add_error("All", msg)
    do_add_error(msg.tag, msg)
    new_log = true
end
local fileserver_ip = {text="0.0.0.0"}
local fileserver_port = {text="2018"}

local log_receiver
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

function m.init_log_receiver()
    if not log_receiver then
        log_receiver = cthread.channel_consume "log_channel"
    end
end

function m.show(rhwi)
    if not err_receiver then
        err_receiver = cthread.channel_consume "errlog"
    end
    
    local error, info = err_receiver:pop()
    if error then
        local count = 1
        for _ in string.gmatch(info, '\n') do
            count = count + 1
        end
        m.error({
            message = "[" .. time2str(os.time()) .. "][Thread]" .. info,
            height = count * log_item_height,
            line_count = count
        })
    end
    --print("ERROR:" .. err:pop())
    --thread.wait(fileserver_thread)

    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - uiconfig.LogWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, uiconfig.LogWidgetHeight, 'F')
    if log_receiver then
        local has, msg = log_receiver:pop()
        while has do
            local level
            local msg_str
            if #msg == 1 then
                local first = string.find(msg[1], "]")
                local second = string.find(msg[1], "]", first + 1)
                local rawlevel = string.sub(msg[1], first + 2, second - 1)
                level = rawlevel:match'^%s*(.*%S)' or ''
                level = string.lower(level)
                msg_str = msg[1]
            elseif #msg > 3 then
                level = msg[1]
                msg_str = "[" .. time2str(msg[2]) .. "][" .. level:upper() .. "][".. msg[3] .. "]"
                for i = 4, #msg do
                    msg_str = msg_str .. msg[i]
                end
            end
            local count = 1
            for _ in string.gmatch(msg_str, '\n') do
                count = count + 1
            end
            local item = {
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
    for _ in uiutils.imgui_windows("Log", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if imgui.widget.Button("Clear") then
            reset_log()
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
        local current_log = log_items[current_tag][filter_flag]
        local total_virtual_count = (filter_flag > 0) and #current_log.vtor_index or 0
        if total_virtual_count > 0 then
            imgui.cursor.Separator()
            imgui.windows.SetNextWindowContentSize(0, current_log.height)
            imgui.windows.BeginChild("LogDetail", 0, 0, false, imgui.flags.Window { "HorizontalScrollbar" })
            if new_log then
                new_log = false
                imgui.windows.SetScrollY(imgui.windows.GetScrollMaxY())
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
    end
end

return function(am)
    icons = require "common.icons"(am)
    reset_log()
    --test
    -- for i = 1, 10 do
    --     if i == 5 then
    --         m.info({
    --             message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_\nHello\nWorld" .. i,
    --             height = 3 * log_item_height,
    --             line_count = 3
    --         })
    --     elseif i == 8 then
    --         m.info({
    --             message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_\nWord" .. i,
    --             height = 2 * log_item_height,
    --             line_count = 2
    --         })
    --     elseif i == 9 then
    --         m.info({
    --             message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_\nAAA\nBBB\nCCC\nDDD\nEEE\nFFF" .. i,
    --             height = 7 * log_item_height,
    --             line_count = 7
    --         })
    --     else
    --         m.info({
    --             message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_" .. i,
    --             height = log_item_height,
    --             line_count = 1
    --         })
    --     end
        
    --     -- m.warn({time = os.time(), tag = log_tags[math.random(2, 4)], content = "helloworld_" .. i + 1})
    --     -- m.error({time = os.time(), tag = log_tags[math.random(2, 4)], content = "helloworld_" .. i + 2})
    -- end
    -- for i = 1, 10, 3 do
    --     m.info({
    --         message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_" .. i,
    --         height = log_item_height,
    --         line_count = 1
    --     })
    --     m.warn({
    --         message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_" .. i + 1,
    --         height = log_item_height,
    --         line_count = 1
    --     })
    --     m.error({
    --         message = "[" .. time2str(os.time()) .. "][".. log_tags[math.random(2, 4)] .. "]" .. "helloworld_" .. i + 2,
    --         height = log_item_height,
    --         line_count = 1
    --     })
    -- end
    --
    return m
end