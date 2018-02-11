dofile "libs/init.lua"
require "iupluaimglib"
iup.SetGlobal("UTF8MODE", "YES")
iup.SetGlobal("UTF8MODE_FILE", "YES")

local fs = require "filesystem"
local toolset = require "editor.toolset"
local path = toolset.load_config()
local seri = require "filesystem.serialize"

local function filetree(filter)
	local dir_view = iup.tree {
		HIDEBUTTONS = "yes",
		HIDELINES = "yes",
	}
	local file_view = iup.list {
		expand = "yes",
	}

	local current_path = nil
	local current_info = {}

	local function load_path()
		local config_name = toolset.homedir .. "/shaderc.lua"
		local config = seri.load(config_name) or {}
		if not config.drive then
			return
		end
		local info = current_info[config.drive]
		if not info then
			return
		end
		current_path = info
		if config.path then
			for k,v in ipairs(config.path) do
				info.path[k] = v
			end
		end
	end

	local function save_path()
		local config_name = toolset.homedir .. "/shaderc.lua"
		seri.save(config_name, {
			drive = current_path.drive,
			path = current_path.path,
		})
	end

	local function switch_drive(name)
		current_path = assert(current_info[name])
	end

	local function reflush_filelist(filelist)
		file_view[1] = nil
		local pat = "%." .. filter .. "$"
		local index = 1
		while filelist[index] do
			if not filelist[index]:match(pat) then
				local n = #filelist
				filelist[index] = filelist[n]
				filelist[n] = nil
			else
				index = index + 1
			end
		end

		if next(filelist) == nil then
			return
		end

		table.sort(filelist)
		for k, v in ipairs(filelist) do
			file_view[k] = v
		end
	end

	--- directory tree

	local function is_dir(pathname)
		return fs.attributes(pathname, "mode") == "directory"
	end

	local function rebuild_tree(drive)
		switch_drive(drive)
		dir_view.delnode0 = "CHILDREN"
		dir_view.title0 = current_path.drive_name
		local index = 0
		local pathname = current_path.drive
		for _,v in ipairs(current_path.path) do
			if is_dir(pathname..v) then
				dir_view["addbranch"..index] = v
				index = index + 1
				pathname = pathname .. v .. "/"
			else
				break
			end
		end
		dir_view.value = index
		local subdir = {}
		local filelist = {}
		-- todo: capture dir error
		for name in fs.dir(pathname) do
			if name ~= "." and name ~= ".." then
				if is_dir(pathname .. name) then
					table.insert(subdir, name)
				else
					table.insert(filelist, name)
				end
			end
		end
		if next(subdir) then
			table.sort(subdir)
			local addbranch = "addleaf" .. index
			local image = "image" .. (index + 1)
			for i = #subdir, 1, -1 do
				dir_view[addbranch] = subdir[i]
				dir_view[image] = "IMGCOLLAPSED"
			end
		end

		reflush_filelist(filelist)

		save_path()

		function dir_view:executeleaf_cb(id)
			local subindex = id - index
			table.insert(current_path.path, subdir[subindex])
			rebuild_tree(drive)
		end

		function dir_view:branchclose_cb(id)
			for i = id + 1, #current_path.path do
				current_path.path[i] = nil
			end
			rebuild_tree(drive)
			return iup.IGNORE
		end
	end

	--- drive list
	local function drives()
		local d = fs.drives()
		local ret = {}
		for k,v in ipairs(d) do
			local item = { drive = v, name = v }
			local name = d[v]
			if name then
				item.name = v .. " " .. name
			end
			current_info[v] = {
				drive = v,
				drive_name = item.name,
				path = {},
			}
			table.insert(ret, item)
		end
		return ret
	end

	local function drive_list(d)
		local init = {}
		local current = 1
		for k,v in ipairs(d) do
			init[k] = v.name
			if current_path and v.name == current_path.drive then
				current = k
			end
		end
		init.value = current
		init.dropdown = "YES"
		init.visible_items = #init + 1
		init.expand = "HORIZONTAL"
		local ctrl = iup.list(init)
		switch_drive(d[current].drive)
		-- todo: action

		function ctrl:action(name, index, state)
			if state == 1 then
				rebuild_tree(d[index].drive)
			end
		end

		return ctrl
	end

	local dlist = drives()
	load_path()
	return {
		view = iup.vbox {
			drive_list(dlist),
			iup.split {
				dir_view,
				file_view,
				ORIENTATION = "HORIZONTAL",
				SHOWGRIP = "NO",
			},
		},
		rebuild = function()
			rebuild_tree(current_path.drive)
		end
	}
end

----------- fileview & output ------






------------------------------------

local tree = filetree "sc"

local dlg = iup.dialog {
	tree.view,
	margin = "4x4",
	size = "QUARTERxHALF",
	shrink="yes",
	title = "Shader Compiler",
}


dlg:showxy(iup.CENTER,iup.CENTER)

tree.rebuild()

iup.MainLoop()
iup.Close()
