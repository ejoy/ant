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
	if cache_rootpath then
		filepath = path.join(cache_rootpath, filepath)
	end
	path.create_dirs(filepath)
	return filepath
end

local function write_cache(cachedir, cache)
	local function dir_format(filename, s)
		return string.format("d %s %s\n", s, filename)
	end
	local rootfile = path.join(cachedir, "root")
	path.create_dirs(rootfile)
	fu.write_to_file(rootfile, dir_format(cache.filename, cache.sha1), "wb")

	local function write_sha1_file(cache)
		local branchpath = gen_subpath_fromsha1(cache.sha1, cachedir)

		local content = ""
		for _, item in ipairs(cache) do
			local itemcontent
			if item.type == "d" then
				write_sha1_file(item)
				itemcontent = dir_format(item.filename, item.sha1)
			else
				local filepath = gen_subpath_fromsha1(item.sha1, cachedir)
				itemcontent = string.format("f %s %s %d\n", item.sha1, item.filename, item.timestamp)
				fu.write_to_file(filepath, itemcontent, "wb")
			end
			content = content .. itemcontent
		end

		fu.write_to_file(branchpath, content, "wb")
	end

	write_sha1_file(cache)
end

function repo:init(root)
	self.root = root
	local cachedir = path.join(root, ".repo")
	self.cachedir = cachedir
	self:rebuild_index(root)
	write_cache(cachedir, self.cache)
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

function repo:read_cache()
	self.localcache = {}
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()	-- init can be omit
	for _, item in ipairs(array) do
		encoder:update(item.sha1)
	end

	return sha12hex_str(encoder:final())
end

local function build_index(subpath, rootpath, cache)
	local hashtable = {}

	local function update_cache(s, item)
		local exist_item = cache[s]
		if exist_item then
			print("same item found, exist item path : ", exist_item.filename, ", will be overwrite by : ", item.filename)
		end
		cache[s] = item
	end

	local curfolderpath = path.join(rootpath, subpath)
	for name in fs.dir(curfolderpath) do
		if name ~= "." and name ~= ".." and name ~= ".repo" then
			local curpath = path.join(subpath, name)
			local fullpath = path.join(curfolderpath, name)

			local item
			if path.isdir(fullpath) then
				item = build_index(curpath, rootpath, cache)
			else
				local content = read_file_content(fullpath)
				local s = sha1(content)
				item = {type="f", filename=curpath, sha1=s, timestamp=fu.last_modify_time(fullpath)}
				update_cache(s, item)
			end
			table.insert(hashtable, item)
		end
	end

	table.sort(hashtable, function (lhs, rhs) return lhs.filename < rhs.filename end)
	
	local pathsha1 = sha1_from_array(hashtable)
	hashtable.sha1 = pathsha1
	hashtable.filename = subpath
	hashtable.type = "d"

	update_cache(pathsha1, hashtable)	
	return hashtable
end

function repo:rebuild_index()
	local rootpath = self.root
	assert(path.isdir(rootpath))
	self.extand_cache = {}	
	self.cache = build_index(".", rootpath, self.extand_cache)
end

function repo:load(hashkey)
	local cache = assert(self.extand_cache)
	local item = cache[hashkey]
	if item == nil then
		error(string.format("not found hash : %s", hashkey))
	end

	return item.filename
end

function repo:load_root()
	local root = assert(self.cache)
	local s = assert(root.sha1)
	local rootpath = path.join(self.cachedir, sha1_to_path(s))
	assert(fs.exist(rootpath))
	return rootpath	
end

return repo