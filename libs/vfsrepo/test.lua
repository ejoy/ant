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
local f1_sha1 = sha1(string.format("%s %s %s", "f", f1_1_sha1, "f1_1.txt"))

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
	
	fs.remove(file1)
	fs.remove(file2)
	fs.remove(newtestfolder)
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
end

--file sha1 value is the same as folder sha1
do
	local newtestfolder = path.join(testfolder, "test4")
	path.create_dirs(newtestfolder)

	local spfolder = path.join(newtestfolder, "sp")
	local file1, file2 = path.join(spfolder, "1.txt"), path.join(spfolder, "2.txt")
	fu.write_to_file(file1, "1.txt", "wb")
	fu.write_to_file(file2, "2.txt", "wb")

	local s1, s2 = sha1(file1), sha1(file2)
	local t1, t2 = fu.last_modify_time(file1), fu.last_modify_time(file2)
	local specialfile = paht.join(newtestfolder, "sp.txt")
	local specialcontent = ""
	specialcontent = specialcontent .. string.format("f %s %s\n", s1, "1.txt")
	specialcontent = specialcontent .. string.format("f %s %s\n", s2, "2.txt")

	fu.write_to_file(specialfile, specialcontent, "wb")
	local sp_sh1 = sh1(specialfile)

	local repo4 = vfsrepo.new(newtestfolder)
	repo4:load()
end