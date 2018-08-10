local repo = {}
repo.__index = repo

local fs = require "filesystem"
local fu = require "filesystem.util"
local path = require "filesystem.path"
local crypt = require "crypt"

function repo.new()
	return setmetatable({}, repo)
end

local function write_cache(cachedir, cache)
	path.create_dirs(cachedir)
	local rootpath = path.join(self.cachedir, "root")
	local rootfile = io.open(rootpath, "wb")
	local root_sha1 = cache.root
	rootfile:write(root_sha1)
	rootfile:close()

	local function write_sha1_file(cache)
		for k, item in pairs(cache) do
			local ktype = type(k)
			local s
			local content = ""
			if ktype == "string" then
				s = item.sha1
				local foldername = s:sub(1, 2)
				local filepath = path.join(cachedir, foldername, s)
				content = content .. string.format("d %s %s", filepath, s)
				write_sha1_file(item.dirs)
			else
				assert(ktype == "number")
				s = item.sha1

				content = content .. string.format("%s %s %s %d\n", item.type, item.filename, item.sha1, item.timestamp)
			end

			local foldername = s:sub(1, 2)
			local filepath = path.join(cachedir, foldername, s)
			path.create_dirs(filepath)
			local ff = io.open(filepath, "wb")
			ff:write(content)
			ff:close()				
		end
	end

	write_sha1_file(cache)
end

function repo:init(root)
	self.root = root
	self.cachedir = path.join(root, ".repo")
	self:rebuild_index(root)
	write_cache(self.cachdir, self.cache)
end

local function read_file_content(filename)
	local ff = io.open(filename, "rb")
	local content = ff:read "a"
	ff:close()
	return content
end

local function byte2hex(c)
	return string.format("%02X", c:byte())
end

local function sha12hex_str(s)
	return s:gsub(".", byte2hex):lower()
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
	return {type="f", filename=fullpath, sha1=s, timestamp=fu.last_modify_time(fullpath)}
end

local function sort_items(dirs)		
	local ff = {}
	local dd = {}

	for k, f in pairs(dirs) do
		if type(k) == "string" then
			table.insert(dd, {filename=k, sha1=f.sha1})
		else
			assert(f.type == "f")
			table.insert(ff, f)
		end
	end

	local comp = function(lhs, rhs) return lhs.filename < rhs.filename end 
	table.sort(ff, comp)
	table.sort(dd, comp)

	table.move(dd, 1, #dd, #ff+1, ff)
	return ff
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()	-- init can be omit
	for _, item in ipairs(array) do
		encoder:update(item.sha1)
	end

	return sha12hex_str(encoder:final())
end

local function build_index(filepath, cache)
	local hashtable = {}

	for name in fs.dir(filepath) do
		local fullpath = filepath .. "/" .. name
		if name ~= "." and name ~= ".." then
			local item
			if path.isdir(fullpath) then
				local dirs = build_index(fullpath, cache)				
			
				local result = sort_items(dirs)
				local s = sha1_from_array(result)
				item = {type="d", filename=fullpath, sha1=s}
				hashtable[fullpath] = {sha1=s, dirs=dirs}
			else
				item = create_item(fullpath)
				table.insert(hashtable, item)				
			end

			cache[item.sha1] = item
		end
	end

	return hashtable
end

function repo:rebuild_index()
	assert(path.isdir(self.root))
	self.extand_cache = {}
	self.cache = build_index(self.root, self.extand_cache)

	local function build_root_index(cache)
		local result = {}
		sort_items(cache, result)
		return sha1_from_array(result)		
	end

	self.cache.root = build_root_index(self.cache)
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
	return assert(self.cache).root
end


return repo