local editor_mainwindow = require 'editor.controls.window'
local fs = require "filesystem"

local iupex = {}

function iupex.menu(t, bind)
    local nt = {}
    for _, item in ipairs(t) do
        if type(item) == 'string' then
            nt[#nt+1] = {item}
        elseif type(item) == 'table' then
            local click = item[2]
            if type(click) == 'table' then
                item[2] = iupex.menu(click, bind)
            elseif type(click) == 'userdata' then
                item[2] = click
            elseif bind and type(click) == 'string' then
                item[2] = function(e)
                    if bind.on and bind.on.click then
                        bind.on.click(e, click)
                    end
                end
            end
            nt[#nt+1] = item
        end 
    end
    return iup.menu(nt)
end

local CMD = {}
local config = {}
config.recent = {}

local bind = {on = {}}
function bind.on.click(e, name)
    if CMD[name] then
        CMD[name](e)
    end
end

local guiRecent = iupex.menu({
    {"Clean Recently Opened", "CleanRecentlyOpened"},
    {},
}, bind)

local guiMain = iupex.menu(
{
    {
        "File",
        {
            {"Open Map...", "OpenMap"},
            {"Open Recent", guiRecent},
        } 
    },
}, bind)

local guiOpenMap = iup.GetChild(iup.GetChild(guiMain, 0), 0)

local openMap

local function recentSave()
    fs.mkdir './config/'
    local f = io.open('./config/recent.cfg', 'w')
    if not f then
        return
    end
    for _, path in ipairs(config.recent) do
        f:write(path .. '\n')
    end
    f:close()
end

local function recentUpdate()
    while true do
        local h = iup.GetChild(guiRecent, 2)
        if h then
            iup.Detach(h)
        else
            break
        end
    end
    for _, path in ipairs(config.recent) do
        local h = iup.item {
            title = path,
            action = function()
                openMap(path)
            end
        }
        iup.Append(guiRecent, h) 
        iup.Map(h)
    end
end

local function recentAdd(path)
    table.insert(config.recent, 1, path)
    for i = 2, 10 do
        if config.recent[i] == path then
            table.remove(config.recent, i)
            return
        end
    end
    config.recent[11] = nil
end

local function recentAddAndUpdate(path)
    recentAdd(path)
    recentUpdate()
    recentSave()
end

local function recentInit()
    config.recent = {}
    local f = io.open('./config/recent.cfg', 'r')
    if not f then
        return
    end
    for path in f:lines() do
        table.insert(config.recent, path)
    end
    f:close()
    recentUpdate()
end

function openMap(path)
    guiOpenMap.active = "OFF"
    guiRecent.active = "OFF"
    recentAddAndUpdate(path)
    editor_mainwindow:new_world {
        path, 
        "engine.module", 
        "editor.module"
    }
end

function CMD.OpenMap(e)
    local filedlg = iup.filedlg
    {
        dialogtype = "OPEN",
        filter = "*.module",
        filterinfo = "Map File",
        parentdialog = iup.GetDialog(e),
    }
    filedlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)
    if tonumber(filedlg.status) ~= -1 then
        openMap(filedlg.value)
    end

    filedlg:destroy()
end

function CMD.CleanRecentlyOpened(e)
    config.recent = {}
    recentUpdate()
    recentSave()
end

recentInit()

return guiMain
