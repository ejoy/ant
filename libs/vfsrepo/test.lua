dofile("libs/init.lua")

local vfsrepo = require "vfsrepo"

local repo = vfsrepo.new()


local testfolder = "libs/vfsrepo/test"
repo:init(testfolder)

local crypt = require "crypt"

local ff = io.open(testfolder .. "/f0/f0_1.txt")

local content = ff:read "a"

ff:close()


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

local s = sha1(content)

local result = repo:load(s)

print(result)