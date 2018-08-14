local repo = {}
repo.__index = repo

local fs = require "filesystem"
local fu = require "filesystem.util"
local path = require "filesystem.path"
local crypt = require "crypt"

function repo.new()
	return setmetatable({}, repo)
end

local function sha1_to_path(s)
	local foldername = s:sub(1, 2)
	return path.join(foldername, s)
end

local function gen_subpath_fromsha1(s, cache_rootpath)
	local filepath = sha1_to_path(s)
	filepath = path.join(cache_rootpath, filepath)	
	path.create_dirs(path.parent(filepath))
	return filepath
end

local function write_cache(cachedir, cache)	
	path.create_dirs(cachedir)
	local rootfile = path.join(cachedir, "root")	
	fu.write_to_file(rootfile, cache.sha1, "wb")

	local function write_sha1_file(cache)
		local branchpath = gen_subpath_fromsha1(cache.sha1, cachedir)

		local content = ""
		for _, item in ipairs(cache) do
			local itemcontent
			if item.type == "d" then
				write_sha1_file(item)
				itemcontent = string.format("d %s %s\n", item.sha1, path.filename(item.filename))
			else
				local filepath = gen_subpath_fromsha1(item.sha1, cachedir) .. ".ref"
				fu.write_to_file(filepath, string.format("%s %d\n", item.filename, item.timestamp), "wb")

				itemcontent = string.format("f %s %s %d\n", item.sha1, path.filename(item.filename), item.timestamp)
			end
			content = content .. itemcontent
		end
		fu.write_to_file(branchpath, content, "wb")
	end

	write_sha1_file(cache)
end

function repo:init(root)
	self.rootpath = root
	local cachedir = path.join(root, ".repo")
	self.cachedir = cachedir
	self:read_cache()
	if self:rebuild_index(root) then
		write_cache(cachedir, self.cache)
	end
end

function repo:close()
	self.rootpath = nil
	self.cachedir = nil
	self.cache = nil
	self.hash_cache = nil
	self.localcache = nil
end

local function read_file_content(filename)
	local ff = io.open(filename, "rb")
	local content = ff:read "a"
	ff:close()
	return content
end

local function byte2hex(c)
	return string.format("%02x", c:byte())
end

local function sha12hex_str(s)
	return s:gsub(".", byte2hex)
end

local function sha1(str)
	local sha1 = crypt.sha1(str)
	return sha12hex_str(sha1)
end

function repo:remove_localcache()
	self.localcache = {}
end

function repo:read_cache()
	if not fs.exist(self.cachedir) then
		return
	end

	local rootfile = path.join(self.cachedir, "root")
	local rootsha1 = read_file_content(rootfile)	
	assert(rootsha1:find("[^%da-f]") == nil)

	local function read_tree_branch(pathsha1, dirname, cache)
		local children = {}
		local rootsha1path = path.join(self.cachedir, sha1_to_path(pathsha1))
		for line in io.lines(rootsha1path) do
			local elems = {}	-- [1] ==> type, [2] ==> sha1, [3] ==> dir/file name, [4](opt) ==> file timestamp
			for m in line:gmatch("[^%s]+") do
				table.insert(elems, m)
			end
			assert(#elems >= 3)
			local filename = path.join(dirname, elems[3])
	
			local item 
			if elems[1] == "d" then	
				item = read_tree_branch(elems[2], filename, cache)
			else
				assert(#elems == 4 and elems[1] == "f")
				item = {type="f", sha1=elems[2], timestamp=math.tointeger(elems[4])}
			end

			children[filename] = item
		end

		return {type="d", children=children, sha1=pathsha1,}
	end

	self.localcache = read_tree_branch(rootsha1, "")
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()	-- init can be omit
	for _, item in ipairs(array) do
		encoder:update(item.sha1)
	end

	return sha12hex_str(encoder:final())
end

function repo:build_index(filepath)
	local hash_cache = self.hash_cache
	local localcache = self.localcache
	local rootpath = self.rootpath
	local hashtable = {}

	local function update_cache(s, item)
		-- local exist_item = hash_cache[s]
		-- if exist_item then
		-- 	print("same item found, exist item path : ", exist_item.filename, ", will be overwrite by : ", item.filename)
		-- end
		hash_cache[s] = item
	end

	local branch_modify = false
	local currentpath = path.join(rootpath, filepath)
	for name in fs.dir(currentpath) do
		if name ~= "." and name ~= ".." and name ~= ".repo" then
			local function create_item()
				local itempath = path.join(filepath, name)
				local fullpath = path.join(rootpath, itempath)
				if path.isdir(fullpath) then
					return self:build_index(itempath)
				end

				local function file_sha1(timestamp)
					if localcache then
						local localitem = localcache[itempath]
						
						if 	localitem and
							timestamp == localitem.timestamp then

							return localitem.sha1, false
						end
					end

					local content = read_file_content(fullpath)
					return sha1(content), true
				end

				local timestamp = fu.last_modify_time(fullpath)
				local s, modify = file_sha1(timestamp)
				local item = {type="f", filename=itempath, sha1=s, timestamp=timestamp}

				update_cache(s, item)
				return item, modify
			end

			local item, modify = create_item()
			branch_modify = branch_modify or modify
			table.insert(hashtable, item)
		end
	end

	table.sort(hashtable, function (lhs, rhs) return lhs.filename < rhs.filename end)

	local function path_sha1()
		if localcache then
			local localitem = localcache[filepath]
			if localitem and (not branch_modify) then
				return localitem.sha1
			end
		end
		return sha1_from_array(hashtable)
	end
	local pathsha1 = path_sha1()
	hashtable.sha1 = pathsha1
	hashtable.filename = filepath
	hashtable.type = "d"

	update_cache(pathsha1, hashtable)
	return hashtable, branch_modify
end

function repo:rebuild_index()
	local rootpath = self.rootpath
	assert(path.isdir(rootpath))
	self.hash_cache = {}
	local modified
	self.cache, modified = self:build_index("", rootpath, self.localcache, self.hash_cache)
	return modified
end

function repo:load(hashkey)
	local cache = assert(self.hash_cache)
	local item = cache[hashkey]
	if item == nil then
		error(string.format("not found hash : %s", hashkey))
	end

	if item.type == "d" then
		local cachedir = assert(self.cachedir)
		local filepath = gen_subpath_fromsha1(assert(item.sha1), cachedir)
		if not fs.exist(filepath) then
			error("load from value type: internal error")
		end
		return filepath
	end
	return item.filename
end

function repo:root_hash()
	local root = assert(self.cache)
	return assert(root.sha1)
end

function repo:load_root()
	local root = assert(self.cache)
	local s = assert(root.sha1)
	local rootpath = path.join(self.cachedir, sha1_to_path(s))
	assert(fs.exist(rootpath))
	return rootpath	
end

return repo