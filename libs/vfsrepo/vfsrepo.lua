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

local function refpath_from_sha1(cachedir, s)
	return path.join(cachedir, sha1_to_path(s)) .. ".ref"	
end


function repo:write_cache()	
	local cachedir = self.cachedir
	local cache = self.cache
	path.create_dirs(cachedir)
	local rootfile = path.join(cachedir, "root")	
	fu.write_to_file(rootfile, cache.sha1, "wb")

	local function write_sha1_file(cache)		
		

		local content = ""
		for _, item in ipairs(cache) do
			local itemcontent
			if item.type == "d" then
				write_sha1_file(item)
				itemcontent = string.format("d %s %s\n", item.sha1, path.filename(item.filename))
			else
				local s = item.sha1
				local function line_format(item)
					return string.format("%s %d\n", item.filename, item.timestamp)
				end
				local function write_ref_file()
					local refpath = refpath_from_sha1(cachedir, s)
					if not fs.exist(refpath) then
						path.create_dirs(path.parent(refpath))
						local dcache = self.duplicate_cache
						if dcache then
							local ditems = dcache[s]
							if ditems then
								local refcontent = ""
								for _, item in ipairs(ditems) do
									refcontent = refcontent .. line_format(item)
								end
								fu.write_to_file(refpath, refcontent, "wb")
								return
							end
						end
						
						fu.write_to_file(refpath, line_format(item), "wb")
					end
				end

				write_ref_file()
				itemcontent = string.format("f %s %s\n", s, path.filename(item.filename))
			end
			content = content .. itemcontent
		end

		-- filter out same folder
		local branchpath = path.join(cachedir, sha1_to_path(cache.sha1))
		if not fs.exist(branchpath) then
			path.create_dirs(path.parent(branchpath))
			fu.write_to_file(branchpath, content, "wb")
		end		
	end

	write_sha1_file(cache)
end

function repo:init(root)
	self.rootpath = root
	local cachedir = path.join(root, ".repo")
	self.cachedir = cachedir
	self:read_cache()
	if self:rebuild_index(root) then
		self:write_cache()
	end
end

function repo:close()
	self.rootpath = nil
	self.cachedir = nil
	self.cache = nil
	self.hash_cache = nil
	self.localcache = nil
	self.duplicate_cache = nil
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

function repo:get_duplicate_cache()
	local dcache = self.duplicate_cache
	if dcache == nil then
		dcache = {}
		self.duplicate_cache = dcache
	end
	return dcache
end

local function read_line_elems(l)
	-- [1] ==> type, [2] ==> sha1, [3] ==> dir/file name(relative to previous folder)
	local elems = {}	
	for m in l:gmatch("[^%s]+") do
		table.insert(elems, m)
	end
	return elems
end

local function read_ref_file_items(s, ref_filepath)
	local refitems = {}
	for ref_line in io.lines(ref_filepath) do
		local refelems = read_line_elems(ref_line)			
		assert(#refelems == 2)	-- refitems[1] ==> filename(relative to root), refitems[2] ==> timestamp
		local f = refelems[1]
		table.insert(refitems, {type="f", sha1=s, filename=f, timestamp=math.tointeger(refelems[2])})
	end

	return refitems
end

local function find_timestampe(refitems, filename)	
	for _,ii in ipairs(refitems) do 
		if ii.filename == filename then 
			return ii.timestamp
		end 
	end
	return nil
end

function repo:update_duplicate_cache(s, refitems)
	if #refitems > 1 then
		local dcache = self:get_duplicate_cache()					
		local ditems = dcache[s]
		if ditems == nil then
			dcache[s] = refitems
		else
			assert(#ditems == #refitems)
			for idx, it in ipairs(refitems) do
				local it0 = ditems[idx]
				assert(it.sha1 == it0.sha1)
			end
		end
	end
end

function repo:read_cache()
	local cachedir = self.cachedir
	if not fs.exist(cachedir) then
		return
	end

	local rootfile = path.join(cachedir, "root")
	local rootsha1 = read_file_content(rootfile)	
	assert(rootsha1:find("[^%da-f]") == nil)

	local function read_tree_branch(pathsha1, dirname, cache)		
		local dirsha1_filepath = path.join(cachedir, sha1_to_path(pathsha1))
		for line in io.lines(dirsha1_filepath) do
			local elems = read_line_elems(line)
			assert(#elems == 3)
			local filename = path.join(dirname, elems[3])
	
			if elems[1] == "d" then	
				read_tree_branch(elems[2], filename, cache)
			else
				assert(elems[1] == "f")
				local s = elems[2]
					
				local ref_filepath = refpath_from_sha1(cachedir, s)
				assert(fs.exist(ref_filepath))

				local refitems = read_ref_file_items(s, ref_filepath)
				local timestamp = find_timestampe(refitems, filename)

				self:update_duplicate_cache(s, refitems)
				cache[filename] = {type="f", sha1=s, timestamp=timestamp}
			end
		end

		cache[dirname] = {type="d", sha1=pathsha1,}
	end

	self.localcache = {}
	read_tree_branch(rootsha1, "", self.localcache)
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()
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
		local exist_item = hash_cache[s]
		if exist_item then
			local dcache = self:get_duplicate_cache()

			local itemlist = dcache[s]
			if itemlist == nil then
				itemlist = {}
				dcache[s] = itemlist
				table.insert(itemlist, exist_item)
			end
			
			table.insert(itemlist, item)
		end
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

					print("cacl item : ", itempath)
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