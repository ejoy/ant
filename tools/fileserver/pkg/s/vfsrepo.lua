local lfs = require "bee.filesystem"
local fastio = require "fastio"

local repo = {}

local function is_resource(path)
	local ext = path:match "%.(%w+)$"
	return ext and (ext == "material" or ext == "glb" or ext == "texture")
end

local function list_files(root, dir, fullpath)
	local n = 1
	for path, attr in lfs.pairs(root) do
		local name = path:filename():string()
		local pathname = path:string()
		local obj = { name = name }
		if is_resource(name) then
			obj.resource = fullpath .. "/" .. name
		elseif attr:is_directory() then
			local d = {}
			list_files(pathname, d, fullpath .. "/" .. name)
			obj.dir = d
		else
			obj.path = pathname
		end
		dir[n] = obj; n = n + 1
	end
	return dir
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
			dir[item.name] = item
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

local function calc_file_hash(item)
	local timestamp = lfs.last_write_time(item.path)
	if item.timestamp == timestamp then
		if item.hash then
			return
		end
	end
	item.timestamp = timestamp
	item.hash = fastio.sha1(item.path)
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
			calc_file_hash(item)
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
	local hashs = {}
	local function make_index_(dir)
		for _, item in ipairs(dir) do
			if item.hash then
				hashs[item.hash] = item
			end
			if item.dir then
				make_index_(item.dir)
			end
		end
	end
	make_index_(root)
	return hashs
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
					item.timestamp = timestamp
					item.hash = sha1
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
	root._hash = make_hash_index(root._dir)
	root._hash[root._root.hash] = root._root
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

function repo_meta:init(config)
	local hashs = config.hash
	self._dir = {}
	list_files(config[1].path, make_dir(self._dir, config[1].mount), config[1].mount)
	for i = 2, #config do
		local tmp = {}
		list_files(config[i].path, tmp, config[i].mount)
		merge_dir(make_dir(self._dir, config[i].mount), tmp)
	end
	sort_dir(self._dir)
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

function repo_meta:dir(hash)
	local item = self._hash[hash]
	return item and item.content
end

function repo_meta:localpath(hash)
	local item = self._hash[hash]
	return item and item.path
end

function repo_meta:type(hash)
	local item = self._hash[hash]
	if item then
		return item.dir and "dir" or "file"
	end
end

function repo_meta:root()
	return self._root.hash
end

function repo_meta:filehash(pathname)
	local path, name = pathname:match "^/?(.-)/([^/]*)$"
	if name == "" then
		pathname = path
		path, name = path:match "^(.-)/([^/]*)$"
	end
	if path == nil or path == "" then
		-- root
		for _, item in ipairs(self._dir) do
			if item.name == pathname then
				return item.hash, item.resource
			end
		end
	else
		local dir = self._index[path .. "/"]
		if dir == nil then
			return
		end
		for _, item in ipairs(dir) do
			if item.name == name then
				return item.hash, item.resource
			end
		end
	end
end

function repo_meta:dumptree()
	return dump_dir(self._dir)
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
	assert(vfsrepo:type(hash) == "dir")
	print("HASH", testpath, hash)
	local content = vfsrepo:dir(hash)
	print("CONTENT", testpath, content)
	assert(vfsrepo:localpath(hash) == nil)
	local filehash, path = vfsrepo:filehash(testpath .. "/line.material")
	assert(filehash == nil)
	print("RESOURCEPATH", path)
	local cache = vfsrepo:export_hash()
	print("INIT WITH CACHE")
	init_config.hash = cache
	vfsrepo:init(init_config)
end

return repo
