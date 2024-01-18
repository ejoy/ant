local lfs = require "bee.filesystem"
local fastio = require "fastio"

local repo = {}

local DOT <const> = string.byte "."
local SLASH <const> = string.byte "/"

local EMPTY = {}

local function gen_set(s)
	if not s then
		return EMPTY
	end
	local r = {}
	for _, name in ipairs(s) do
		r[name] = true
	end
	return r
end

local function init_filter(f)
	return {
		block = gen_set(f.block),
		ignore = gen_set(f.ignore),
		resource = gen_set(f.resource),
		whitelist = gen_set(f.whitelist),
	}
end

local function list_files(root, dir, fullpath, filter)
	if filter and filter.ignore[fullpath] then
		filter = nil
	end
	local oldn = #dir
	local n = 1
	for path, attr in lfs.pairs(root) do
		local name = path:filename():string()
		if name:byte() == DOT then
			goto continue
		end
		local fullpath_name = fullpath .. "/" .. name
		if filter and filter.block[fullpath_name] then
			goto continue
		end
		local pathname = path:string()
		local ext = name:match "%.([^./]+)$" or ""
		local obj = { name = name }
		if attr:is_directory() then
			local d = {}
			list_files(pathname, d, fullpath_name, filter)
			if d[1] == nil then
				-- empty dir
				goto continue
			end
			obj.dir = d
		elseif filter and filter.resource[ext] then
			obj.resource = fullpath .. "/" .. name
			obj.resource_path = pathname
		else
			if filter and not filter.whitelist[ext] then
				goto continue
			end
			obj.path = pathname
			local timestamp = attr:last_write_time()
			if timestamp ~= obj.timestamp then
				obj.timestamp = timestamp
				obj.hash = nil
			end
		end

		dir[n] = obj; n = n + 1
		::continue::
	end
	for i = n, oldn do
		dir[i] = nil
	end
end

local function patch_list_files(root, dir, fullpath, filter)
	local oldn = #dir
	local n = 1
	for path, attr in lfs.pairs(root) do
		local name = path:filename():string()
		local obj
		if name:byte() == DOT then
			goto continue
		end
		local fullpath_name = fullpath .. "/" .. name
		if filter.block[fullpath_name] then
			goto continue
		end
		local pathname = path:string()
		local ext = name:match "%.([^./]+)$" or ""

		if attr:is_directory() then
			-- new dir
			local d = {}
			list_files(pathname, d, fullpath_name, filter)
			if d[1] == nil then
				goto continue
			end
			obj = {
				dir = d,
				name = name,
			}
		elseif filter.resource[ext] then
			obj = {
				name = name,
				resource = fullpath .. "/" .. name
			}
		else
			if not filter.whitelist[ext] then
				goto continue
			end
			obj = {
				name = name,
				path = pathname,
				timestamp = attr:last_write_time(),
			}
		end
		dir[n] = obj; n = n + 1
		::continue::
	end
	for i = n, oldn do
		dir[i] = nil
	end
end

local function deep_copy(dir)
	local subdir = dir.dir
	if subdir == nil then
		return dir
	end
	local clone = {}
	for k,v in pairs(dir) do
		clone[k] = v
	end
	local clonedir = {}
	for i = 1, #subdir do
		clonedir[i] = deep_copy(subdir[i])
	end
	clone.dir = clonedir
	return clone
end

local function merge_dir(source, patch)
	local dir = {}
	local n = #source
	for i = 1, n do
		local item = source[i]
		dir[item.name] = item
	end
	for _, item in ipairs(patch) do
		local s = dir[item.name]
		if s and s.dir and item.dir then
			merge_dir(s.dir, item.dir)
		else
			dir[item.name] = deep_copy(item)
		end
	end
	local nn = 1
	for _ , item in pairs(dir) do
		source[nn] = item; nn = nn + 1
	end
	for i = nn, n do
		source[i] = nil
	end
end

local function sort_name(a,b)
	return a.name < b.name
end

local function sort_dir(dir)
	table.sort(dir, sort_name)
	for i = 1, #dir do
		local item = dir[i]
		if item.dir then
			sort_dir(item.dir)
		end
	end
end

local function read_dir(paths)
	local dir = {}
	for _, root in ipairs(paths) do
		for path in lfs.pairs(root) do
			local name = path:filename():string()
			local pathname = path:string()
			if not dir[name] then
				dir[name] = pathname
			end
		end
	end
	return dir
end

local function dump_dir(dir)
	local r = {}
	local n = 1
	local function dump_(d, ident)
		local next_ident = ident .. "  "
		for _, item in ipairs(d) do
			r[n] = ident .. item.name; n = n + 1
			if item.dir then
				dump_(item.dir, next_ident)
			end
		end
	end
	dump_(dir, "")
	return table.concat(r, "\n")
end

local function calc_hash(dir)
	local n = #dir
	local dir_content = {}
	for i = 1, n do
		local item = dir[i]
		if item.resource then
			dir_content[i] = "r " .. item.name .. " " .. item.resource .. "\n"
		elseif item.dir then
			item.content = calc_hash(item.dir)
			item.hash = fastio.str2sha1(item.content)
			dir_content[i] = "d " .. item.name .. " " .. item.hash .. "\n"
		else
			if not item.hash then
				item.hash = fastio.sha1(item.path)
			end
			dir_content[i] = "f " .. item.name .. " " .. item.hash .. "\n"
		end
	end
	return table.concat(dir_content)
end

local function export_hash(root, name)
	local result = {}
	local function export_(dir, prefix)
		for _, item in ipairs(dir) do
			if item.dir then
				export_(item.dir, prefix .. item.name .. "/")
			elseif item.hash and item.path then
				local path = item.path
				if name then
					path = path .. name
				end
				result[path] = { item.hash, item.timestamp }
			end
		end
	end
	export_(root, "")
	return result
end

local function make_index(root)
	local index = { [""] = root }
	local function make_index_(r, prefix)
		for _, item in ipairs(r.dir) do
			if item.dir then
				local path = prefix .. item.name .. "/"
				index[path] = item
				make_index_(item, path)
			end
		end
	end
	make_index_(root, "")
	return index
end

local function import_hash(index, hashs, name)
	for _, r in pairs(index) do
		for _, item in ipairs(r.dir) do
			if item.path then
				local fullpath = item.path
				if name then
					fullpath = fullpath .. name
				end
				local h = hashs[fullpath]
				if h and item.timestamp == h[2] then
					item.hash = h[1]
				end
			end
		end
	end
end

local repo_meta = {}; repo_meta.__index = repo_meta

local function update_all(root, hashs)
	local root_content = hashs ~= false and calc_hash(root._dir)
	root._root = {
		name = "",
		content = root_content,
		hash = root_content and fastio.str2sha1(root_content),
		dir = root._dir,
	}
	root._index = make_index(root._root)
end

local function change_dir_(dir, name)
	local n = #dir
	for i = 1, n do
		local item = dir[i]
		if item.name == name then
			if item.dir == nil then
				error ("Can't create dir " .. name)
			end
			return item.dir
		end
	end
	local r = { name = name, dir = {} }
	dir[n+1] = r
	return r.dir
end

local function make_dir(dir, path)
	for name in path:gmatch "[^/]+" do
		dir = change_dir_(dir, name)
	end
	return dir
end

function repo.new()
	return setmetatable({}, repo_meta)
end

local function append_slash(path)
	if path:sub(-1) ~= '/' then
		return path .. '/'
	else
		return path
	end
end

local function add_path(self, paths)
	local subroot = {}
	local i = 1
	for _, p in ipairs(paths) do
		local filter
		if p.filter then
			filter = init_filter(p.filter)
		else
			filter = self._filter or error "Need filter"
		end
		local mount = append_slash(p.mount)
		local vfspath = mount:sub(1, -2)
		if not filter.block[vfspath] then
			local root = {}
			local path = append_slash(p.path)
			list_files(path, root, vfspath, filter)
			if root[1] then
				-- at least one file
				subroot[i] = {
					path = path,
					mount = mount,
					root = root,
					filter = filter,
				} ; i = i + 1
			end
		end
	end
	self._subroot = subroot
end

local function merge_all(self)
	local result = {}
	for i = 1, #self._subroot do
		local sub = self._subroot[i]
		merge_dir(make_dir(result, sub.mount), sub.root)
	end
	sort_dir(result)
	self._dir = result
end

local function split_path(path)
	local from, to, name = path:find "([^/]+)/?$"
	if not from then
		return ""
	end
	if path:byte() == SLASH then
		path = path:sub(2, from - 1)
	else
		path = path:sub(1, from - 1)
	end
	return path, name
end

function repo_meta:file(pathname)
	local path, name = split_path(pathname)
	if name == nil then
		return self._root
	end
	local dir = self._index[path]
	if dir == nil then
		return
	end
	for _, item in ipairs(dir.dir) do
		if item.name == name then
			return item
		end
	end
end

function repo_meta:valid_path(path)
	local index = self._index
	local name
	while true do
		path, name = split_path(path)
		local dir = index[path]
		if dir then
			for _, item in ipairs(dir.dir) do
				if item.name == name then
					return "/" .. path .. name, item
				end
			end
			return "/" .. path, dir
		end
	end
end

local function find_subroot(self, localpath)
	if localpath:sub(-1) ~= '/' then
		localpath = localpath .. "/"
	end
	for _, sub in ipairs(self._subroot) do
		if localpath == sub.path then
			-- full root update
			return "", sub
		elseif localpath:sub(1, #sub.path) == sub.path then
			-- sub path update
			local path = localpath:sub(#sub.path+1)
			return path, sub
		end
	end
	-- ignore localpath
end

local function update_localpath(self, localpath)
	local path, sub = find_subroot(self, localpath)
	if path and not sub.filter.block[path] then
		patch_list_files(localpath, make_dir(sub.root, path), path, sub.filter)
	end
end

function repo_meta:vpath(localpath)
	local path, sub = find_subroot(self, localpath)
	if path == nil then
		return
	end
	if localpath:sub(-1) ~= '/' then
		path = path:sub(1, -2)
	end
	local vpath = sub.mount .. path
	local f = self:file(vpath)
	return f.path == localpath, vpath
end

function repo_meta:update(list)
	for _, path in ipairs(list) do
		update_localpath(self, path)
	end
	merge_all(self)
	update_all(self)
end

function repo_meta:init(config)
	local hashs = config.hash
	self._name = config.name and ("@" .. config.name)
	self._dir = {}
	self._subroot = {}
	if config.filter then
		self._filter = init_filter(config.filter)
	end
	add_path(self, config)
	merge_all(self)
	if hashs then
		local index = make_index { dir = self._dir }
		import_hash(index, hashs, self._name)
	end
	update_all(self, hashs)
end

function repo_meta:export_hash()
	assert(self._dir)
	local hashs = export_hash(self._dir, self._name)
	return hashs
end

function repo_meta:import_hash(hashs)
	assert(self._index)
	import_hash(self._index, hashs, self._name)
end

function repo_meta:root()
	return self._root.hash
end

function repo_meta:dumptree()
	return dump_dir(self._dir)
end

function repo_meta:resources()
	local names = {}
	local paths = {}
	local n = 1
	local function get_resource_(dir, prefix)
		for _, item in ipairs(dir) do
			if item.dir then
				local path = prefix .. item.name .. "/"
				get_resource_(item.dir, path)
			elseif item.resource then
				names[n] = item.resource
				paths[n] = item.resource_path
				n = n + 1
			end
		end
	end
	get_resource_(self._dir, "")
	return names, paths
end

function repo_meta:export()
	local r = {
		{ vpath = "/" , hash = self._root.hash, dir = self._root.content },
	}
	local n = 2
	local function make_index_(dir, path)
		for _, item in ipairs(dir) do
			local fullpath = path .. item.name
			if item.hash then
				if item.content then
					r[n] = { vpath = fullpath, hash = item.hash, dir = item.content }
				else
					r[n] = { vpath = fullpath, hash = item.hash, path = item.path }
				end
				n = n + 1
			end
			if item.dir then
				make_index_(item.dir, fullpath .. "/" )
			end
		end
	end
	make_index_(self._root.dir, "/")
	return r
end

function repo.calc_hash(list)
	local dir_content = {}
	for i = 1, #list do
		local item = list[i]
		if item.type == "dir" then
			dir_content[i] = "d " .. item.name .. " " .. item.hash .. "\n"
		else
			assert(item.type == "file")
			dir_content[i] = "f " .. item.name .. " " .. item.hash .. "\n"
		end
	end
	local c = table.concat(dir_content)
	local h = fastio.str2sha1(c)
	return { content = c, hash = h }
end

return repo
