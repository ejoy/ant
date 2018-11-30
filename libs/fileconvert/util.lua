local util = {}; util.__index = util

local path = require "filesystem.path"
local fu = require "filesystem.util"
local vfs = require "vfs"

local exts = {
	sc = true,
	fbx = true,
	bin = true,
}

function util.need_build(srcfilepath)
	local ext = path.ext(srcfilepath)
	if ext then
		ext = ext:lower()
		if exts[ext] then
			local lk = srcfilepath .. ".lk"
			local r = vfs.realpath(lk)
			if fu.exist(r) then
				return true
			end
			error(string.format("src:%s, need lk file, but not provided", srcfilepath))
		end
	end
end

return util