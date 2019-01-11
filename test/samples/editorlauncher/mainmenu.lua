--luacheck: globals iup import
local asset = import_package "ant.asset"
local vfsutil = require "vfsutil"
local fs = require "filesystem"
local configDir = fs.mydocs_path() / '.ant/config'
fs.create_directories(configDir)
local recentcfg = configDir / 'recent.cfg'

--project related
local editor_mainwindow = require 'mainwindow'

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

local guiFile = iupex.menu({
    {"Open Map...", "OpenMap"},
    {},
    {},
    {"Clean Recently Opened", "CleanRecentlyOpened"},
}, bind)

local guiMain = iupex.menu(
{
    {
        "File",
        guiFile,
    },
}, bind)

local guiOpenMap = iup.GetChild(iup.GetChild(guiMain, 0), 0)
local openMap

local function recentSave()
    local f = fs.open(recentcfg, 'w')
    if not f then
        return
    end
    for _, path in ipairs(config.recent) do
        f:write(path:string() .. '\n')
    end
    f:close()
end

local function recentUpdate()
    local ref = iup.GetChild(guiFile, iup.GetChildCount(guiFile) - 2)
    for _, path in ipairs(config.recent) do
        local h = iup.item {
            title = path:string(),
            action = function()
        		openMap(path)
            end
        }
        guiFile:insert(ref, h) 
        iup.Map(h)
    end
end

local function recentAdd(path)
	local filterpath = vfsutil.filter_abs_path(path)
    table.insert(config.recent, 1, filterpath)
    for i = 2, 10 do
        if config.recent[i] == filterpath then
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
    local f, err = fs.open(recentcfg, 'r')
    if not f then
		print(err)
        return
    end
    for p in f:lines() do
        table.insert(config.recent, fs.path(p))
    end
    f:close()
    recentUpdate()
end

function openMap(path)
	guiOpenMap.active = "OFF"
	recentAddAndUpdate(path)

	path = vfsutil.filter_abs_path(path)

    local mapcfg = fs.dofile(path)

    local packages = {
        "ant.EditorLauncher",
        "ant.objcontroller",
        "ant.hierarchy.offline",
    }
    local systems = {
        "pickup_material_system",
        "pickup_system",
        "obj_transform_system",
        "build_hierarchy_system",
        "editor_system"
    }
    if mapcfg.name ~= "ant.EditorLauncher" then
        local pm = require "antpm"
        pm.register(path:parent_path())
    end
    packages[#packages+1] = mapcfg.name
    table.move(mapcfg.systems, 1, #mapcfg.systems, #systems+1, systems)
    editor_mainwindow:new_world(packages, systems)
end

local function popup_select_file_dlg(parentdlg, filepattern, seletfileop)
	local filedlg = iup.filedlg
    {
        dialogtype = "OPEN",
        filter = filepattern,
        filterinfo = "Map File",
        parentdialog = parentdlg,
	}
	
	filedlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)
	if tonumber(filedlg.status) ~= -1 then
		seletfileop(fs.path(filedlg.value))
	end
	filedlg:destroy()
end

function CMD.OpenMap(e)
	popup_select_file_dlg(iup.GetDialog(e), "package.lua", openMap)
end

function CMD.CleanRecentlyOpened(e)
    config.recent = {}
    recentUpdate()
    recentSave()
end

recentInit()

return guiMain
