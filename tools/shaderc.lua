dofile "libs/init.lua"
require "iupluaimglib"
iup.SetGlobal("UTF8MODE", "YES")
iup.SetGlobal("UTF8MODE_FILE", "YES")

local fs = require "filesystem"


local function filetree()
	local dir_view = iup.tree {
		HIDEBUTTONS = "yes",
		HIDELINES = "yes",
	}
	local file_view = iup.list {
		expand = "yes",
	}

	local current_path = nil
	local current_info = {}

	local function switch_drive(name)
		current_path = assert(current_info[name])
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
			pathname = pathname .. v
			if is_dir(pathname) then
				dir_view["addbranch"..index] = v
				index = index + 1
				pathname = pathname .. "/"
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

		file_view[1] = nil
		if next(filelist) then
			table.sort(filelist)
			for k, v in ipairs(filelist) do
				file_view[k] = v
			end
		end

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

	local function drive_list()
		local init = {}
		local d = drives()
		for k,v in ipairs(d) do
			init[k] = v.name
		end
		init.value = 1
		init.dropdown = "YES"
		init.visible_items = #init + 1
		init.expand = "HORIZONTAL"
		local ctrl = iup.list(init)
		switch_drive(d[1].drive)
		-- todo: action

		function ctrl:action(name, index, state)
			if state == 1 then
				rebuild_tree(d[index].drive)
			end
		end

		return ctrl
	end

	return {
		view = iup.vbox {
			drive_list(),
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

local tree = filetree()

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
