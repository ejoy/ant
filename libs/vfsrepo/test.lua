dofile("libs/init.lua")

local vfsrepo = require "vfsrepo"
local path = require "filesystem.path"

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