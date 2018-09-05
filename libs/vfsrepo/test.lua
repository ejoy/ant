dofile("libs/init.lua")

local vfsrepo = require "vfsrepo"
local path = require "filesystem.path"
local fu = require "filesystem.util"
local fs = require "filesystem"

local repo = vfsrepo.new()


local testfolder = "libs/vfsrepo/test"
repo:init(testfolder)

local crypt = require "crypt"

local function filecontent(name)
	local ff = io.open(name)
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

local f1_1_sha1 = sha1(filecontent(path.join(testfolder, "f1/f1_1.txt")))
local f1_sha1 = sha1(string.format("%s %s %s\n", "f", f1_1_sha1, "f1_1.txt"))

local result = repo:load(f1_1_sha1)
assert(result == "f1/f1_1.txt")
print(repo:load(f1_sha1))

--------------------------------------

do
	local newtestfolder = path.join(testfolder, "test2")
	path.create_dirs(newtestfolder)
	local file1, file2 = path.join(newtestfolder, "test1.txt"), path.join(newtestfolder, "test2.txt")

	fu.write_to_file(file1, "file1", "wb")
	fu.write_to_file(file2, "file2", "wb")

	local repo2 = vfsrepo.new()
	repo2:init(newtestfolder)

	local hash_cache = repo2.hash_cache
	repo2:close()

	fu.write_to_file(file1, "adfhadfasdf", "wb")
	repo2:init(newtestfolder)
	local hash_cache2 = repo2.hash_cache

	for key, hitem in pairs(hash_cache) do
		local newitem = hash_cache2[key]
		if newitem == nil then
			print("key : ", key, ", not found after rebuild index")	
		end
	end
	
	repo2:gc()

	local function list_all_sha1(folder)
		local sha1list = {}
		local function filter(subfolder)
			for name in path.dir(subfolder, {"root"}) do
				local fullpath = path.join(subfolder, name)
				if path.isdir(fullpath) then
					filter(fullpath)
				else
					local ext = path.ext(name)			
					if ext == "ref" then
						local n = path.filename_without_ext(name)
						sha1list[n] = "f"
					else
						sha1list[name] = "d"
					end					
				end
			
			end
		end
		filter(folder)
		return sha1list
	end

	local sha1list = list_all_sha1(path.join(newtestfolder, ".repo"))
	for k, v in pairs(sha1list) do
		assert(repo2:load(k))
	end

	path.remove(newtestfolder)
end

--test duplicate hash------------------------------------------
do
	local newtestfolder = path.join(testfolder, "test3")
	path.create_dirs(newtestfolder)
	local file1, file2 = path.join(newtestfolder, "test1.txt"), path.join(newtestfolder, "test2.txt")

	fu.write_to_file(file1, "file1", "wb")
	fu.write_to_file(file2, "file1", "wb")

	local folder1 = path.join(newtestfolder, "dup1")
	local folder2 = path.join(newtestfolder, "dup2")
	path.create_dirs(folder1)
	path.create_dirs(folder2)

	local dfile1 = path.join(folder1, "dfile1.txt")
	local dfile2 = path.join(folder2, "dfile2.txt")

	fu.write_to_file(dfile1, "dfile", "wb")
	fu.write_to_file(dfile2, "dfile", "wb")

	local repo3 = vfsrepo.new()
	repo3:init(newtestfolder)

	local dcache = repo3.duplicate_cache
	for key, itemlist in pairs(dcache) do
		print("duplicate key : ", key)
		for _, item in ipairs(itemlist) do
			print("type : ", item.type, ", filename : ", item.filename)
		end
	end

	path.remove(newtestfolder)
end

local function sha1_from_array(array)
	local encoder = crypt.sha1_encoder():init()
	for _, item in ipairs(array) do
		local content = string.format("%s %s %s\n", item.type, item.sha1, path.filename(item.filename))
		encoder:update(content)
	end

	return sha12hex_str(encoder:final())
end

local function folder_sha1(subfolder)
	local function gen_item_list(subfolder)
		local t = {}
		for name in path.dir(subfolder, {".repo"}) do
			local fullpath = path.join(subfolder, name)
			local item
			if path.isdir(fullpath) then
				item = gen_item_list(fullpath)
			else
				item = {type="f", filename=name, sha1=sha1(filecontent(fullpath))}
			end
	
			table.insert(t, item)
		end
	
		table.sort(t, function (lhs, rhs) return lhs.filename < rhs.filename end)
	
		t.filename = path.filename(subfolder)
		t.type = "d"
		t.sha1 = sha1_from_array(t)
		return t
	end

	local items = gen_item_list(subfolder)
	local encoder = crypt.sha1_encoder():init()

	for _, it in ipairs(items) do
		local content = string.format("%s %s %s\n", it.type, it.sha1, it.filename)
		encoder:update(content)
	end

	return sha12hex_str(encoder:final())
end


--file sha1 value is the same as folder sha1
do
	local newtestfolder = path.join(testfolder, "test4")
	path.create_dirs(newtestfolder)

	local spfolder = path.join(newtestfolder, "sp")
	path.create_dirs(spfolder)
	local file1, file2 = path.join(spfolder, "1.txt"), path.join(spfolder, "2.txt")
	fu.write_to_file(file1, "1.txt", "wb")
	fu.write_to_file(file2, "2.txt", "wb")

	local s1, s2 = sha1(filecontent(file1)), sha1(filecontent(file2))
	local t1, t2 = fu.last_modify_time(file1), fu.last_modify_time(file2)
	local specialfile = path.join(newtestfolder, "sp.txt")
	local specialcontent = ""
	specialcontent = specialcontent .. string.format("f %s %s\n", s1, "1.txt")
	specialcontent = specialcontent .. string.format("f %s %s\n", s2, "2.txt")

	fu.write_to_file(specialfile, specialcontent, "wb")
	local sp_sh1 = sha1(specialcontent)

	local repo4 = vfsrepo.new(newtestfolder)
	local ditems = repo4.duplicate_cache[sp_sh1]
	assert(#ditems)	-- folder sp and sp.txt have the same sha1

	path.remove(newtestfolder)
end

do
	local newtestfolder = path.join(testfolder, "test5")
	path.create_dirs(newtestfolder)

	local f1folder = path.join(newtestfolder, "f1")
	local f2folder = path.join(newtestfolder, "f2")
	path.create_dirs(f1folder)
	path.create_dirs(f2folder)

	local f1, f2 = path.join(f1folder, "1.txt"), path.join(f2folder, "2.txt")
	fu.write_to_file(f1, f1, "wb")
	fu.write_to_file(f2, f2, "wb")

	local repo5 = vfsrepo.new(newtestfolder)
	local hash = folder_sha1(newtestfolder)

	local items = repo5:list_items(hash)
	for _, i in ipairs(items) do
		print(i)
	end

	path.remove(newtestfolder)

end