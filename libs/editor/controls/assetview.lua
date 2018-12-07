local assetview = {}; assetview.__index = assetview
local listctrl = require "editor.controls.listctrl"

local path = require "filesystem.path"
local fu = require "filesystem.util"
local lfs = require "lfs"
local vfs = require "vfs"

function assetview:restype_ctrl()
	local ctrl = iup.GetChild(self.view, 0)
	assert(ctrl.NAME == "RES_TYPE")
	return ctrl.owner
end

function assetview:reslist_ctrl()
	local ctrl = iup.GetChild(self.view, 1)
	assert(ctrl.NAME == "RES_LIST")
	return ctrl.owner	
end

function assetview:init(defaultrestype)
	local restype = assert(self:restype_ctrl())
	local reslist = assert(self:reslist_ctrl())
	
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
		return {projectdir, enginedir}
	end

	local function is_rootdir(dir)
		local dirs = rootdirs()
		for _, d in ipairs(dirs) do
			if dir == d then
				return true
			end
		end
		return false
	end

	local function is_subdir(dir)
		local dirs = rootdirs()
		local dir = dir:lower()
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
		
		iup.Map(l.list)
	end

	function restype.list:valuechanged_cb()
		local rt = self.VALUESTRING
		update_res_list(reslist, get_rootdir_from_restype(rt), rt)
	end

	update_res_list(reslist, get_rootdir_from_restype(defaultrestype), defaultrestype)

	function reslist.list:dblclick_cb(item, text)
		local ud = reslist:get_ud(item)
		update_res_list(reslist, ud.path, ud.restype)
	end
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
	local reslist = listctrl.new {NAME="RES_LIST"}
	local restype = listctrl.new {NAME="RES_TYPE", DROPDOWN="YES"}
	restype.list.EXPAND = "HORIZONTAL"

	local assetview = iup.vbox {
		restype.list,
		reslist.list,
		NAME="ASSETVIEW",
		EXPANED="ON",
	}
	return {view=assetview}
end

function assetview.new(config)
	local av = create(config)
	av.view.owner = av
	return setmetatable(av, assetview)
end

return assetview