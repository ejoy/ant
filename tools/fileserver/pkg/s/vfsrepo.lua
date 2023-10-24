local lfs = require "bee.filesystem"
local fastio = require "fastio"

local repo = {}

local function is_resource(path)
	local ext = path:match "%.(%w+)$"
	return ext and (ext == "material" or ext == "glb" or ext == "texture")
end

local DOT <const> = string.byte "."

local function list_files(root, dir, fullpath)
	local oldn = #dir
	local n = 1
	for path, attr in lfs.pairs(root) do
		local name = path:filename():string()
		if name:byte() ~= DOT then
			local pathname = path:string()
			local obj = { name = name }
			if attr:is_directory() then
				local d = {}
				list_files(pathname, d, fullpath .. "/" .. name)
				obj.dir = d
			elseif is_resource(name) then
				obj.resource = fullpath .. "/" .. name
			else
				obj.path = pathname
				local timestamp = attr:last_write_time()
				if timestamp ~= obj.timestamp then
					obj.timestamp = timestamp
					obj.hash = nil
				end
			end
			dir[n] = obj; n = n + 1
		end
	end
	for i = n, oldn do
		dir[i] = nil
	end
end

local function patch_list_files(root, dir, fullpath)
	local tmp = {}
	local oldn = #dir
	local n = 1
	for i = 1, oldn do
		local item = dir[i]
		if item.dir then
			tmp[item.name] = item
		end
	end
	for path, attr in lfs.pairs(root) do
		local name = path:filename():string()
		local obj
		if name:byte() ~= DOT then
			local pathname = path:string()
			if attr:is_directory() then
				obj = tmp[name]
				if not obj then
					-- new dir
					local d = {}
					list_files(pathname, d, fullpath .. "/" .. name)
					obj = {
						dir = d,
						name = name,
					}
				end
			elseif is_resource(name) then
				obj = {
					name = name,
					resource = fullpath .. "/" .. name
				}
			else
				obj = {
					name = name,
					path = pathname,
					timestamp = attr:last_write_time(),
				}
			end
			dir[n] = obj; n = n + 1
		end
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

local function export_hash(root)
	local result = {}
	local n = 1
	local function export_(dir, prefix)
		for _, item in ipairs(dir) do
			if item.dir then
				export_(item.dir, prefix .. item.name .. "/")
			elseif item.hash then
				result[n] = string.format("%s%s %s %d\n", prefix, item.name, item.hash, item.timestamp) ; n = n + 1
			end
		end
	end
	export_(root, "")
	return table.concat(result)
end

local function make_index(root)
	local index = { ["/"] = root }
	local function make_index_(dir, prefix)
		for _, item in ipairs(dir) do
			if item.dir then
				local path = prefix .. item.name .. "/"
				index[path] = item.dir
				make_index_(item.dir, path)
			end
		end
	end
	make_index_(root, "")
	return index
end

local function make_hash_index(root)
	local dir_hashs = {}
	local file_hashs = {}
	local function make_index_(dir)
		for _, item in ipairs(dir) do
			if item.hash then
				if item.content then
					dir_hashs[item.hash] = item.content
				else
					file_hashs[item.hash] = item.path
				end
			end
			if item.dir then
				make_index_(item.dir)
			end
		end
	end
	make_index_(root)
	return dir_hashs, file_hashs
end

local function import_hash(index, hashs)
	local root = assert(index["/"])
	for line in hashs:gmatch "(.-)\n+" do
		local path, sha1, timestamp = line:match "(%S+) (%S+) (%S+)"
		timestamp = tonumber(timestamp)
		local prefix, name = path:match "(.*/)([^/]+)$"
		if not prefix then
			prefix = ""
			name = path
		end
		local d = index[prefix]
		if d then
			for _, item in ipairs(d) do
				if item.name == name then
					if item.timestamp == timestamp then
						item.hash = sha1
					end
					break
				end
			end
		end
	end
end

local repo_meta = {}; repo_meta.__index = repo_meta

local function update_all(root)
	local root_content = calc_hash(root._dir)
	root._root = {
		name = "",
		content = root_content,
		hash = fastio.str2sha1(root_content),
		dir = root._dir,
	}
	root._index = make_index(root._dir)
	root._dhash, root._fhash = make_hash_index(root._dir)
	root._dhash[root._root.hash] = assert(root._root.content)
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
	for i, p in ipairs(paths) do
		local root = {}
		local path = append_slash(p.path)
		local mount = append_slash(p.mount)
		subroot[i] = {
			path = path,
			mount = mount,
			root = root,
		}
		list_files(path, root, mount:sub(1, -2))
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

function repo_meta:file(pathname)
	local path, name = pathname:match "^/?(.-)/([^/]*)$"
	if name == "" then
		pathname = path
		path, name = path:match "^(.-)/([^/]*)$"
	end
	if path == nil or path == "" then
		-- root
		for _, item in ipairs(self._dir) do
			if item.name == pathname then
				return item, self._dir
			end
		end
		return nil, self._dir
	else
		local dir = self._index[path .. "/"]
		if dir == nil then
			return
		end
		for _, item in ipairs(dir) do
			if item.name == name then
				return item, dir
			end
		end
		return nil, dir
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
	if path then
		patch_list_files(localpath, make_dir(sub.root, path), path)
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
	self._dir = {}
	self._subroot = {}
	add_path(self, config)
	merge_all(self)
	if hashs then
		local index = make_index(self._dir)
		import_hash(index, hashs)
	end
	update_all(self)
end

function repo_meta:export_hash()
	assert(self._dir)
	local hashs = export_hash(self._dir)
	return hashs
end

function repo_meta:import_hash(hashs)
	assert(self._index)
	import_hash(self._index, hashs)
end

function repo_meta:root()
	return self._root.hash
end

function repo_meta:dumptree()
	return dump_dir(self._dir)
end

function repo_meta:hash_dirs(tbl)
	for hash, content in pairs(self._dhash) do
		tbl[hash] = content
	end
end

function repo_meta:hash_files(tbl)
	for hash, path in pairs(self._fhash) do
		tbl[hash] = path
	end
end

local function test()	-- for reference
	local init_config = {
		{ path = "/ant/test/vfsrepo", mount = "/" },
		{ path = "/ant/pkg", mount = "/pkg" },
	}

	print("INIT")
	local vfsrepo = repo.new()
	vfsrepo:init(init_config)
	local roothash = vfsrepo:root()
	print("ROOT", roothash)
	local testpath = "/pkg/ant.resources/materials"
	local hash = vfsrepo:filehash(testpath)
	assert(vfsrepo._dhash[hash])
	print("HASH", testpath, hash)
	local content = vfsrepo._dhash[hash]
	print("CONTENT", testpath, content)
	assert(vfsrepo._fhash[hash] == nil)
	local filehash, path = vfsrepo:filehash(testpath .. "/line.material")
	assert(filehash == nil)
	print("RESOURCEPATH", path)
	local cache = vfsrepo:export_hash()
	print("INIT WITH CACHE")
	init_config.hash = cache
	vfsrepo:init(init_config)
	print("UPDATE")
	vfsrepo:update {
		"/ant/pkg/ant.window",
	}
	print(vfsrepo:vpath("/ant/pkg/ant.window/main.lua"))
end

return repo
