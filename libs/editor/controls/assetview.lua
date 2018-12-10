--luachecks: globals iup
local assetview = {}; assetview.__index = assetview
local listctrl = require "editor.controls.listctrl"

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

function assetview:init(defaultrestype)
	local restype = assert(self:restype_ctrl())
	local reslist = assert(self:reslist_ctrl())
	local addrview = assert(self:addrview_ctrl())
	
	restype:append_item("engine")
	restype:append_item("project")

	defaultrestype = defaultrestype or "project"
	assert(defaultrestype == "project" or defaultrestype == "engine")
	restype.list.VALUESTRING = defaultrestype

	local function get_rootdir_from_restype(rt)
		return rt == "project" and lfs.currentdir() or vfs.realpath("engine/assets")
	end

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

	function restype.list:valuechanged_cb()
		local rt = self.VALUESTRING
		update_res_list(reslist, get_rootdir_from_restype(rt), rt)		
	end

	local rootdir = get_rootdir_from_restype(defaultrestype)
	update_res_list(reslist, rootdir, defaultrestype)
	addrview:update("/" .. defaultrestype)

	function reslist.list:dblclick_cb(item, text)
		local ud = reslist:get_ud(item)
		local rt = ud.restype
		local filepath = ud.path
		update_res_list(reslist, filepath, rt)
		if fu.isdir(filepath) then
			local rootdir = get_rootdir_from_restype(rt)		
			local respath = filepath:gsub(rootdir, "/" .. rt)
			addrview:update(respath)
		end
	end

	addrview:add_click_address_cb("update_reslist", function (url)
		local rt = restype.list.VALUESTRING
		local rootdir, found = url:gsub("^/project", lfs.currentdir())
		if found == 0 then
			rootdir, found = url:gsub("^/engine", vfs.realpath("engine/assets"))
			if found == 0 then
				error(string.format("invalid url:%s", url))
			end
		end
		update_res_list(reslist, rootdir, rt)
	end)
end

function assetview:which_res_content()
	local restype = self:restype_ctrl()
	return restype.list.VALUESTRING
end

function assetview:get_select_res()
	local reslist = self:restype_ctrl()
	return reslist.list.VALUE
end

local function create(config)
	local reslist = listctrl.new {NAME="RES_LIST", SCROLLBAR="YES", EXPAND="ON"}
	local restype = listctrl.new {NAME="RES_TYPE", DROPDOWN="YES"}
	restype.list.EXPAND = "HORIZONTAL"

	local addr = addrctrl.new()

	local assetview = iup.vbox {
		restype.list,
		addr.view,
		reslist.list,
		NAME="ASSETVIEW",
		EXPANED="ON",
		MINSIZE="120x0"
	}
	return {view=assetview}
end

function assetview.new(config)
	local av = create(config)
	av.view.owner = av
	return setmetatable(av, assetview)
end

return assetview