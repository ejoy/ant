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
	local ff = io.open(path.join(testfolder, name))
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

local f1_1_sha1 = sha1(filecontent("f1/f1_1.txt"))
local f1_sha1 = sha1(f1_1_sha1)

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
end