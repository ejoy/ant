--luacheck: globals iup import
local require = import and import(...) or require

local fs = require "cppfs"
local asset = require "asset"
local vfsutil = require "vfs.util"
local localfs = require "filesystem.file"

local configDir = (os.getenv 'UserProfile') .. '\\.ant\\config\\'

--project related
local editor_mainwindow = require 'test.samples.PVPScene.mainwindow'

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
			{"Open Entry File(*.lua)", "FromEntryFile"},
            {"Open Recent", guiRecent},
            {"Run file", "RunFile"},
        } 
    },
}, bind)

local guiOpenMap = iup.GetChild(iup.GetChild(guiMain, 0), 0)
local guiRunFile = iup.GetChild(iup.GetChild(iup.GetChild(guiMain, 0), 0), 2)
local openMap

local function recentSave()
    fs.create_directories(fs.path(configDir))
    local f = localfs.open(configDir .. 'recent.cfg', 'w')
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
    local f, err = localfs.open(configDir .. 'recent.cfg', 'r')
    if not f then
		print(err)
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
    guiRunFile.active = "ON"
	recentAddAndUpdate(path)

	path = vfsutil.filter_abs_path(path)

	local function load_modules(path)
		local ext = path:match("%.([%w_-]+)$")
		if ext == "module" then
			return asset.load(path)
		end

		assert(ext == "lua")
		return {path:match("(.+)%.lua$")}
	end

	local modules = load_modules(path)
    local editormodules = {
        -- "editor.ecs.camera_controller",
        "editor.ecs.obj_trans_controller",
        "editor.ecs.pickup_system",
        "editor.ecs.general_editor_entities",
        "editor.ecs.build_hierarchy_system",
        "test.samples.PVPScene.editor_system",
    }
    table.move(editormodules, 1, #editormodules, #modules+1, modules)
    editor_mainwindow:new_world(modules)
--[[
    local server_modules = {
        "debugserver.ui_command_component",
        "debugserver.filewatch_system",
        "debugserver.vfs_repo_component",
        "debugserver.vfs_repo_system",
        "debugserver.io_system",
        "debugserver.io_pkg_component",
        "debugserver.io_pkg_handle_system",
        "debugserver.remote_log_system",
        "debugserver.server_debug_system",
        "debugserver.io_pkg_handle_func_component",
    }
    server_main:new_world(server_modules)
--]]
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
		seletfileop(filedlg.value)
	end
	filedlg:destroy()
end

function CMD.OpenMap(e)
	popup_select_file_dlg(iup.GetDialog(e), "*.module", openMap)
end

function CMD.FromEntryFile(e)
	popup_select_file_dlg(iup.GetDialog(e), "*.lua", openMap)
end

local function runFile(file_path)
--    server_main:new_ui_command({"RUN", file_path})
end

function CMD.RunFile(e)
    local filedlg = iup.filedlg
    {
        dialogtype = "OPEN",
        filter = "*.lua",
        filterinfo = "Lua File",
        parentdialog = iup.GetDialog(e),
    }
    filedlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)
    if tonumber(filedlg.status) ~= -1 then
        runFile(filedlg.value)
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
