--luachecks: globals iup
local assetview = {}; assetview.__index = assetview
local listctrl = require "editor.controls.listctrl"
local ctrlutil =require "editor.controls.util"

local path = require "filesystem.path"
local fu = require "filesystem.util"
local lfs = require "lfs"
local vfs = require "vfs"

local addrctrl = require "editor.controls.addressnavigation_ctrl"

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
	return rt == "project" and lfs.currentdir() or vfs.realpath("engine/assets")
end

local function get_vfs_root_path(rt)
	return rt == "project" and "/project" or "/engine/assets"
end

local function get_vfs_path(rt, abspath, withoutroot)
	local rootdir = get_rootdir_from_restype(rt)
	return abspath:gsub(rootdir .. "/", withoutroot and "" or get_vfs_root_path(rt) .. "/")
end

local function get_abs_path(rt, vfspath)
	local rootdir, found = url:gsub("^/project", lfs.currentdir())
	if found == 0 then
		rootdir, found = url:gsub("^/engine/assets", vfs.realpath("engine/assets"))
		if found == 0 then
			return nil
		end
	end

	return rootdir
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
		local projectdir = lfs.currentdir():lower()
		local enginedir = vfs.realpath("engine/assets"):lower()
		return {projectdir:gsub("\\", "/"), enginedir:gsub("\\", "/")}
	end

	local function is_subdir(dir)
		local dirs = rootdirs()
		dir = dir:lower():gsub("\\", "/")		
		for _, rd in ipairs(dirs) do
			if dir:match(rd) and dir ~= rd then
				return true
			end
		end
		return false
	end

	local function update_res_list(l, rootdir, rt)
		if not fu.isdir(rootdir) then
			return 
		end

		l:clear()
		if is_subdir(rootdir) then
			l:append_item("[..]", {path=path.parent(rootdir), restype=rt})
		end	
		
		local dirs, files = {}, {}
		for d in fu.dir(rootdir) do
			local fullpath = path.join(rootdir, d)			
			local ud = {path=fullpath, restype = rt}
			if fu.isdir(fullpath) then
				table.insert(dirs, {'[' .. d .. ']', ud})
			else
				table.insert(files, {d, ud})
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
		if fu.isdir(filepath) then
			addrview:update(get_vfs_path(rt, filepath))
		end
	end

	addrview:add_click_address_cb("update_reslist", function (url)
		local rt = restype.view.VALUESTRING
		local rootdir = get_vfs_path(rt, url)
		update_res_list(reslist, rootdir, rt)
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
		local reslist = listctrl.new {NAME="RES_LIST", SCROLLBAR="YES", EXPAND="ON"}
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