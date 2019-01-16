local fs = require "filesystem"
local localfs = require "filesystem.local"
local vfs = require "vfs"
local configDir = localfs.mydocs_path() / '.ant/config'
localfs.create_directories(configDir)
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
    local f = localfs.open(recentcfg, 'w')
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

local function recentClean()
	local numChild = iup.GetChildCount(guiFile)
	assert(numChild <= 12)
	for i = 1, numChild - 2 do
		iup.Detach(guiFile, i)
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
    local f, err = localfs.open(recentcfg, 'r')
    if not f then
		print(err)
        return
    end
    for p in f:lines() do
        table.insert(config.recent, localfs.path(p))
    end
    f:close()
    recentUpdate()
end

local function load_package(path)
	assert(path:is_absolute(path))

	local mapcfg = localfs.dofile(path)	
	return mapcfg.name, mapcfg.systems
end

function openMap(path)
	guiOpenMap.active = "OFF"
	recentAddAndUpdate(path)

	local pkgname, pkgsystems = load_package(path)

	if pkgname == assert(_PACKAGENAME) then
		iup.Message("Error", "Could not open entry package, or open a package with the same name as entry package")
	end

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

	vfs.remove_mount("currentmap")
	vfs.add_mount("currentmap", path:parent_path())
	local pm = require "antpm"
	pm.register(fs.path "currentmap")
    
    packages[#packages+1] = pkgname
    table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
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
		seletfileop(localfs.path(filedlg.value))
	end
	filedlg:destroy()
end

function CMD.OpenMap(e)
	popup_select_file_dlg(iup.GetDialog(e), "package.lua", openMap)
end

function CMD.CleanRecentlyOpened(e)
	recentClean()
    config.recent = {}
    recentUpdate()
    recentSave()
end

recentInit()

return guiMain
