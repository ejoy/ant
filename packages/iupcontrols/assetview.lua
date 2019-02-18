--luachecks: globals iup
local assetview = {}; assetview.__index = assetview
local listctrl = require "listctrl"
local ctrlutil =require "util"

local fs = require "filesystem"

local addrctrl = require "addressnavigation_ctrl"

function assetview:restype_ctrl()
	local ctrl = iup.GetChild(self.view, 0)
	assert(ctrl.NAME == "RES_TYPE")
	return ctrl.owner
end

function assetview:addrview_ctrl()
	local ctrl = iup.GetChild(self.view, 1)
	assert(ctrl.NAME=="ADDR_NAG")
	return ctrl.owner
end

function assetview:reslist_ctrl()
	local ctrl = iup.GetChild(self.view, 2)
	assert(ctrl.NAME == "RES_LIST")
	return ctrl.owner
end

local function get_rootdir_from_restype(rt)
	return rt == "project" and fs.current_path() or fs.path("engine/assets"):localpath()
end

local function get_vfs_root_path(rt)
	return fs.path(rt == "project" and "/project" or "/engine/assets")
end

local function get_vfs_path(rt, abspath, withoutroot)
	local rootdir = get_rootdir_from_restype(rt)
	local abspathname = abspath:string()
	return fs.path(abspathname:gsub(rootdir:string() .. "/", withoutroot and "" or get_vfs_root_path(rt):string() .. "/"))
end

local function get_local_path(rt, vfspath)
	local vfsroot = get_vfs_root_path(rt)
	local vfsname = vfspath:string():lower()

	return fs.path(vfsname:gsub(vfsroot:string(), get_rootdir_from_restype(rt):string()))
end

function assetview:init(defaultrestype)
	local restype = assert(self:restype_ctrl())
	local reslist = assert(self:reslist_ctrl())
	local addrview = assert(self:addrview_ctrl())

	restype:append_item("engine")
	restype:append_item("project")

	defaultrestype = defaultrestype or "project"
	assert(defaultrestype == "project" or defaultrestype == "engine")
	restype.view.VALUESTRING = defaultrestype

	local function rootdirs()
		local projectdir = fs.current_path():string():lower()
		local enginedir = fs.path("engine/assets"):localpath():string():lower()
		return {projectdir:gsub("\\", "/"), enginedir:gsub("\\", "/")}
	end

	local function is_subdir(dir)
		local dirs = rootdirs()		
		for _, rd in ipairs(dirs) do
			local lowerstr = dir:string():lower()
			if lowerstr:match(rd) and lowerstr ~= rd then
				return true
			end
		end
		return false
	end

	local function update_res_list(l, rootdir, rt)
		if not fs.is_directory(rootdir) then
			return
		end

		l:clear()
		if is_subdir(rootdir) then
			l:append_item("[..]", {path=rootdir:parent_path(), restype=rt})
		end

		local dirs, files = {}, {}		
		for fullpath in rootdir:list_directory() do
			local filename = fullpath:filename()
			local ud = {path=fullpath, restype = rt}
			if fs.is_directory(fullpath) then
				table.insert(dirs, {'[' .. filename:string() .. ']', ud})
			else
				table.insert(files, {filename:string(), ud})
			end
		end

		for _, d in ipairs(dirs) do
			l:append_item(d[1], d[2])
		end

		for _, f in ipairs(files) do
			l:append_item(f[1], f[2])
		end
	end

	function restype.view:valuechanged_cb()
		local rt = self.VALUESTRING
		local rootdir = get_rootdir_from_restype(rt)
		update_res_list(reslist, rootdir, rt)
		addrview:update(get_vfs_root_path(rt))
	end

	local rootdir = get_rootdir_from_restype(defaultrestype)
	update_res_list(reslist, rootdir, defaultrestype)
	addrview:update(get_vfs_root_path(defaultrestype))

	function reslist.view:dblclick_cb(item, text)
		local ud = reslist:get_ud(item)
		local rt = ud.restype
		local filepath = ud.path
		update_res_list(reslist, filepath, rt)
		if fs.is_directory(filepath) then
			addrview:update(get_vfs_path(rt, filepath))
		end
	end

	addrview:add_click_address_cb("update_reslist", function (url)
		local rt = restype.view.VALUESTRING
		assert(type(url) == "userdata")
		local localpath = get_local_path(rt, url)
		update_res_list(reslist, localpath, rt)
	end)
end

function assetview:which_res_content()
	local restype = self:restype_ctrl()
	return restype.view.VALUESTRING
end

function assetview:get_select_res()
	local reslist = self:reslist_ctrl()
	local item = tonumber(reslist.view.VALUE)
	if item == 0 then
		return nil
	end

	local ud = reslist:get_ud(item)	
	return get_vfs_path(ud.restype, ud.path, true)
end

function assetview.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		local reslist = listctrl.new {NAME="RES_LIST", SCROLLBAR="YES", EXPAND="YES"}
		local restype = listctrl.new {NAME="RES_TYPE", DROPDOWN="YES"}
		restype.view.EXPAND = "HORIZONTAL"

		local addr = addrctrl.new()	
		return iup.vbox {
			restype.view,
			addr.view,
			reslist.view,
			NAME="ASSETVIEW",
			EXPANED="ON",
			MINSIZE="120x0"
		}
	end, assetview)
end

return assetview
