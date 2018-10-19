dofile "libs/init.lua"

package.preload.lfs = function() return require "winfile" end

local vfs = dofile "runtime/core/firmware/vfs.lua"
local client_repo = vfs.new( "runtime/core/firmware", "runtime/core/test" )


local vfsrepo = require "vfsrepo"
local server_repo = vfsrepo.new()
server_repo:init "libs/vfsrepo/test"

local root = server_repo:root_hash()
client_repo:changeroot(root)

local function readfile(path)
	print("Read file", path)
	while true do
		local f, hash = client_repo:open(path)
		if f then
			return f
		end
		print("Try to request hash from server repo", hash)
		local realpath = server_repo:load(hash)
		if realpath then
			local f = assert(io.open(realpath, "rb"))
			local content = f:read "a"
			f:close()
			client_repo:write(hash, content)
		else
			print("Hash not exist", hash)
			return
		end
	end
end

local f = readfile "f0/f0_1.txt"
f:close()

