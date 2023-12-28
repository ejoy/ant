local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local utils     = require "common.utils"
local cthread   = require "bee.thread"
local fs        = require "filesystem"
local icons     = require "common.icons"

local m = {
    to_bottom = false
}

local log_tags = {
    "All",
    "Engine",
    "Editor",
    "Runtime",
    "Server",
    "Console"
}
local LEVEL_INFO = 1
local LEVEL_WARN = 2
local LEVEL_ERROR = 3
local level_visible = {
    [LEVEL_INFO] = true,
    [LEVEL_WARN] = true,
    [LEVEL_ERROR] = true
}
local log_item_height
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
local log_count = {}
local logfile
local function log_to_file(msg)
    do return end
    if not logfile then
        logfile = fs.path "/":localpath() / "log.txt"--('%s.log'):format(os_date('%Y_%m_%d_%H_%M_%S_{ms}'))
    end
    --local fp = assert(io.open(logfile:string(), 'a'))
    local fp = assert(io.open(logfile:string(), 'w+'))
    fp:write(msg)
    fp:write('\n')
    fp:close()
end

local is_at_end = true
local scroll_to_end = 0
local function do_add(t, item)
    if is_at_end then
        scroll_to_end = 2
    end
    table.insert(t, item)
end

local function do_add_info(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container, item)
    local lc = log_count[tag]
    lc[LEVEL_INFO] = lc[LEVEL_INFO] + 1
end
local function do_add_warn(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container, item)
    local lc = log_count[tag]
    lc[LEVEL_WARN] = lc[LEVEL_WARN] + 1
end
local function do_add_error(tag, item)
    local container = log_items[tag]
    if not container then return end
    do_add(container, item)
    local lc = log_count[tag]
    lc[LEVEL_ERROR] = lc[LEVEL_ERROR] + 1
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
    log_to_file(msg.message)
    msg.level = LEVEL_INFO
    do_add_info("All", msg)
    do_add_info(msg.tag, msg)
    m.to_bottom = true
end

function m.warn(msg)
    log_to_file(msg.message)
    msg.level = LEVEL_WARN
    do_add_warn("All", msg)
    do_add_warn(msg.tag, msg)
    m.to_bottom = true
end

function m.error(msg)
    log_to_file(msg.message)
    msg.level = LEVEL_ERROR
    do_add_error("All", msg)
    do_add_error(msg.tag, msg)
    m.to_bottom = true
end

local err_receiver
local function reset_log()
    for _, v in ipairs(log_tags) do
        log_items[v] = {}
        log_count[v] = {
            [LEVEL_INFO] = 0,
            [LEVEL_WARN] = 0,
            [LEVEL_ERROR] = 0,
        }
    end
end

local log_receiver
function m.init_log_receiver()
    if not log_receiver then
        log_receiver = cthread.channel "log_channel"
    end
end

local function getlevel(msg_str)
    local level = "info"
    local first = string.find(msg_str, "]")
    if first then
        msg_str = string.gsub(msg_str, "\x1b%[33m", "")
        msg_str = string.gsub(msg_str, "\x1b%[31m", "")
        msg_str = string.gsub(msg_str, "\x1b%[0m", "")
        local second = string.find(msg_str, "]", first + 1)
        if second then
            local rawlevel = string.sub(msg_str, first + 2, second - 1)
            msg_str = string.gsub(msg_str, "%["..rawlevel.."%]", "")
            level = string.lower(rawlevel:match'^%s*(.*%S)' or '')
        end
    end
    return level, msg_str
end

local function checkLog()
    local error, info = err_receiver:pop()
    if error then
        local count = 0
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
            level, msg_str = getlevel(msg[2])
        elseif type == "SERVER" then
            msg_tag = "Server"
            level, msg_str = getlevel(msg[2])
            for i = 5, #msg do
                if i > 5 then
                    msg_str = msg_str .. "    "
                end
                msg_str = msg_str .. msg[i]
            end
        end
        local count = 0
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

local function showHeaderWidget()
    if imgui.widget.Button("Clear") then
        reset_log()
    end
    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Info(" .. tostring(log_count[current_tag][LEVEL_INFO]) .. ")", show_info) then
        level_visible[LEVEL_INFO] = show_info[1]
    end

    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Warn(" .. tostring(log_count[current_tag][LEVEL_WARN]) .. ")", show_warn) then
        level_visible[LEVEL_WARN] = show_warn[1]
    end

    imgui.cursor.SameLine()
    if imgui.widget.Checkbox("Error(" .. tostring(log_count[current_tag][LEVEL_ERROR]) .. ")", show_error) then
        level_visible[LEVEL_ERROR] = show_error[1]
    end

    imgui.cursor.SameLine()
    imgui.widget.Text("Show:")
    imgui.cursor.SameLine()
    imgui.cursor.SetNextItemWidth(120)
    if imgui.widget.BeginCombo("##Show", {current_tag}) then
        for _, tag in ipairs(log_tags) do
            if imgui.widget.Selectable(tag, current_tag == tag) then
                current_tag = tag
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.cursor.Separator()
end

local assetmgr  = import_package "ant.asset"
function m.showLog(name)
    local current_log = log_items[current_tag]
    local total_virtual_count = #current_log
    if total_virtual_count <= 0 then return end
    imgui.windows.BeginChild(name, 0, 0, imgui.flags.Child { "None" }, imgui.flags.Window { "HorizontalScrollbar" })
    local textStart = 0
    for _, item in ipairs(current_log) do
        local textEnd = textStart + #item.message
        if not level_visible[item.level] then
            goto continue
        end
        local color
        if item.level == LEVEL_INFO then
            local imagesize = icons.ICON_INFO.texinfo.width * icons.scale
            imgui.widget.Image(assetmgr.textures[icons.ICON_INFO.id], imagesize, imagesize)
        elseif item.level == LEVEL_WARN then
            local imagesize = icons.ICON_WARN.texinfo.width * icons.scale
            imgui.widget.Image(assetmgr.textures[icons.ICON_WARN.id], imagesize, imagesize)
            color = level_color.warn
        elseif item.level == LEVEL_ERROR then
            local imagesize = icons.ICON_ERROR.texinfo.width * icons.scale
            imgui.widget.Image(assetmgr.textures[icons.ICON_ERROR.id], imagesize, imagesize)
            color = level_color.error
        end
        imgui.cursor.SameLine()
        if color then
            imgui.windows.PushStyleColor(imgui.enum.Col.Text, color[1], color[2], color[3], color[4])
        end
        imgui.widget.Text(item.message)
        if color then
            imgui.windows.PopStyleColor()
        end
        ::continue::
    end
    if scroll_to_end > 0 then
        imgui.windows.SetScrollHereY(1.0)
        scroll_to_end = scroll_to_end - 1
    end
    local eps = 10.0
    is_at_end = (imgui.windows.GetScrollY() + eps) >= imgui.windows.GetScrollMaxY()
    local cpx, cpy = imgui.cursor.GetCursorPos()
    imgui.cursor.SetCursorPos(cpx, cpy + 1)
    imgui.cursor.Dummy(0, 0)
    -- imgui.windows.SetNextWindowContentSize(0, current_log.height)
    -- imgui.windows.BeginChild(name, 0, 0, imgui.flags.Child { "None" }, imgui.flags.Window { "HorizontalScrollbar" })
    -- if m.to_bottom then
    --     imgui.windows.SetScrollY(imgui.windows.GetScrollMaxY())
    --     m.to_bottom = false
    -- end
    -- local scrolly = imgui.windows.GetScrollY()
    -- local aw, ah = imgui.windows.GetWindowContentRegionMax()
    -- local item_count = math.ceil(ah / log_item_height)
    -- local items_to_show = scrolly / log_item_height
    -- local v_start_idx = math.floor(items_to_show) + 1
    -- local max_idx = 1
    -- if total_virtual_count > item_count then
    --     max_idx = total_virtual_count - item_count + 1
    -- end
    -- if v_start_idx > max_idx then
    --     v_start_idx = max_idx
    -- end
    -- local v_end_idx = v_start_idx + item_count + 1
    -- if v_end_idx > #current_log.vtor_index then
    --     v_end_idx = #current_log.vtor_index
    -- end
    -- if v_end_idx > total_virtual_count then
    --     v_end_idx = total_virtual_count
    -- end
    -- local _, remain = math.modf(items_to_show)
    -- local offset = remain + current_log.vtor_index[v_start_idx][2]
    -- if offset < 0 then
    --     offset = 0
    -- end
    -- imgui.cursor.SetCursorPos(nil, scrolly - offset * log_item_height)
    -- local start_idx = current_log.vtor_index[v_start_idx][1]
    -- local end_idx = current_log.vtor_index[v_end_idx][1]
    -- for i = start_idx, end_idx do
    --     local color
    --     local item = current_log[i]
    --     if item.level == LEVEL_INFO then
    --         local imagesize = icons.ICON_INFO.texinfo.width * icons.scale
    --         imgui.widget.Image(assetmgr.textures[icons.ICON_INFO.id], imagesize, imagesize)
    --     elseif item.level == LEVEL_WARN then
    --         local imagesize = icons.ICON_WARN.texinfo.width * icons.scale
    --         imgui.widget.Image(assetmgr.textures[icons.ICON_WARN.id], imagesize, imagesize)
    --         color = level_color.warn
    --     elseif item.level == LEVEL_ERROR then
    --         local imagesize = icons.ICON_ERROR.texinfo.width * icons.scale
    --         imgui.widget.Image(assetmgr.textures[icons.ICON_ERROR.id], imagesize, imagesize)
    --         color = level_color.error
    --     end
    --     imgui.cursor.SameLine()
    --     if color then
    --         imgui.windows.PushStyleColor(imgui.enum.Col.Text, color[1], color[2], color[3], color[4])
    --     end
    --     if imgui.widget.Selectable(item.message, current_select == i) then
    --         current_select = i
    --     end
    --     if current_select == i then
    --         if imgui.windows.BeginPopupContextItem(current_select) then
    --             if imgui.widget.Selectable("Copy", false) then
    --                 imgui.util.SetClipboardText(current_log[current_select].message)
    --             end
    --             imgui.windows.EndPopup()
    --         end
    --     end
    --     if color then
    --         imgui.windows.PopStyleColor()
    --     end
    -- end
    imgui.windows.EndChild()
end

function m.showConsole()
    m.showLog("ConsoleList")
end

function m.get_title()
    return "Log"
end

function m.show()
    if not err_receiver then
        err_receiver = cthread.channel "errlog"
    end
    local viewport = imgui.GetMainViewport()
    if not log_item_height then
        log_item_height = 22 * viewport.DpiScale
    end
    checkLog()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    if imgui.windows.Begin("Log", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) then
        showHeaderWidget()
        m.showLog("LogList")
    end
    imgui.windows.End()
end

function m.close_log()
    --logfile_handle:close()
end

reset_log()

return m