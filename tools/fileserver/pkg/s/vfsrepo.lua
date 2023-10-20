local fs = require "filesystem"
local lfs = require "bee.filesystem"
local fastio = require "fastio"

local repo = {}

local function sort_name(a,b)
	return a.name < b.name
end

local function list_files(root)
	local dir = {}
	local n = 1
	for path, attr in fs.pairs(root) do
		local obj = { name = path:filename():string(), path = path:localpath():string() }
		if attr:is_directory() then
			obj.dir = list_files(path)
		end
		dir[n] = obj; n = n + 1
	end
	table.sort(dir, sort_name)
	return dir
end

local function update_files(dir_index, pathname)
	local root = fs.path("/" .. pathname)
	local dir = assert(dir_index[pathname .. "/"], pathname)
	local dir_name = {}
	local n = 1
	local index = {}
	for _, item in ipairs(dir) do
		index[item.name] = item
	end
	for path, attr in fs.pairs(root) do
		local name = path:filename():string()
		local item = index[name]
		local inexist = item == nil
		if inexist then
			item = { name = name, path = nil }
			index[name] = item
		end
		item.path = path:localpath():string()
		if attr:is_directory() then
			if inexist then
				item.dir = list_files(path)
			elseif not item.dir then
				-- old version is not a dir
				item.hash = nil
				item.timestamp = nil
				item.dir = list_files(path)
			end
		else
			item.dir = nil
		end
		dir_name[n] = item.name; n = n + 1
	end
	table.sort(dir_name)
	for i = 1, n-1 do
		dir[i] = index[dir_name[i]]
	end
	for i = n, #dir do
		dir[i] = nil
	end
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
		if item.dir then
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

local root = {}

local function update_all()
	local root_content = calc_hash(root.dir)
	root.root = {
		name = "",
		content = root_content,
		hash = fastio.str2sha1(root_content),
		dir = root.dir,
	}
	root.index = make_index(root.dir)
	root.hash = make_hash_index(root.dir)
	root.hash[root.root.hash] = root.root
end

function repo.init(hashs)
	root.dir = list_files(fs.path "/")
	if hashs then
		local index = make_index(root.dir)
		import_hash(index, hashs)
	end
	update_all(hashs)
end

function repo.export_hash()
	assert(root.dir)
	local hashs = export_hash(root.dir)
	return hashs
end

function repo.import_hash(hashs)
	assert(root.index)
	import_hash(root.index, hashs)
end

local function trim_pathname(pathname)
	return (pathname:match "^/?(.-)/?$")
end

function repo.update(pathname)
	pathname = trim_pathname(pathname)
	assert(root.index)
	update_files(root.index, pathname)
	update_all()
end

function repo.dir(hash)
	local item = root.hash[hash]
	return item and item.content
end

function repo.localpath(hash)
	local item = root.hash[hash]
	return item and item.path
end

function repo.type(hash)
	local item = root.hash[hash]
	if item then
		return item.dir and "dir" or "file"
	end
end

function repo.root()
	return root.root.hash
end

function repo.filehash(pathname)
	local path, name = pathname:match "^/?(.-)/([^/]*)$"
	if name == "" then
		pathname = path
		path, name = path:match "^(.-)/([^/]*)$"
	end
	if path == nil or path == "" then
		-- root
		for _, item in ipairs(root.dir) do
			if item.name == pathname then
				return item.hash
			end
		end
	else
		local dir = root.index[path .. "/"]
		if dir == nil then
			return
		end
		for _, item in ipairs(dir) do
			if item.name == name then
				return item.hash
			end
		end
	end
end

local function test()	-- for reference
	local fs = require "filesystem"
	local vfsrepo = require "vfsrepo"
	vfsrepo.init()
	vfsrepo.update("/pkg")
	local roothash = vfsrepo.root()
	print("ROOT", roothash)
	local testpath = "/pkg/ant.window"
	local hash = vfsrepo.filehash(testpath)
	assert(vfsrepo.type(hash) == "dir")
	print("HASH", testpath, hash)
	local content = vfsrepo.dir(hash)
	print("CONTENT", testpath, content)
	print("LOCALPATH", vfsrepo.localpath(hash))
	local filehash = vfsrepo.filehash(testpath .. "/" .. "main.lua")
	assert(vfsrepo.type(filehash) == "file")
	local content = vfsrepo.dir(filehash)
	assert(content == nil)
	local localpath = vfsrepo.localpath(filehash)
	print("LOCALPATH", localpath)
	local cache = vfsrepo.export_hash()
	print("INIT WITH CACHE")
	vfsrepo.init(cache)
end

return repo
