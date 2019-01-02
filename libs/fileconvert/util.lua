local util = {}; util.__index = util
local vfs = require "vfs"
local fs = require "filesystem"

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
			if fs.exists(r) then
				return true
			end
			error(string.format("src:%s, need lk file, but not provided", srcfilepath))
		end
	end
end

return util