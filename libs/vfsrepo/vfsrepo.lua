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
		return string.format("d %s %s\n", filename, s)
	end
	local rootpath = path.join(cachedir, "root")
	path.create_dirs(rootpath)
	fu.write_to_file(rootpath, dir_format(cache.filename, cache.sha1), "wb")

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
				itemcontent = string.format("f %s %s %d\n", item.filename, item.sha1, item.timestamp)
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
	
end

local function create_item(fullpath)
	local content = read_file_content(fullpath)
	local s = sha1(content)
	return {type="f", filename=fullpath, sha1=s, timestamp=fu.last_modify_time(fullpath), originpath=fullpath}
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()	-- init can be omit
	for _, item in ipairs(array) do
		encoder:update(item.sha1)
	end

	return sha12hex_str(encoder:final())
end

local function build_index(filepath, cache, cachedir)
	local hashtable = {}

	for name in fs.dir(filepath) do
		local fullpath = filepath .. "/" .. name
		if name ~= "." and name ~= ".." and name ~= ".repo" then
			local item
			if path.isdir(fullpath) then
				item = build_index(fullpath, cache, cachedir)
			else
				item = create_item(fullpath, cachedir)
				cache[item.sha1] = item
			end
			table.insert(hashtable, item)
		end
	end

	table.sort(hashtable, function (lhs, rhs) return lhs.originpath < rhs.originpath end)
	local pathsha1 = sha1_from_array(hashtable)
	hashtable.sha1 = pathsha1
	hashtable.filename = path.join(cachedir, sha1_to_path(pathsha1))
	hashtable.type = "d"
	hashtable.originpath = filepath

	cache[pathsha1] = hashtable
	return hashtable
end

function repo:rebuild_index()
	assert(path.isdir(self.root))
	self.extand_cache = {}
	self.cache = build_index(self.root, self.extand_cache, self.cachedir)
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