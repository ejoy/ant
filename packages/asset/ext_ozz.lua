local vfs = require "vfs"
local assetmgr = require "asset"

return function(pkgname, filepath)
	local fn = assetmgr.find_asset_path(pkgname, filepath)

	local function find_tagop(filepath, readops)
		local f = io.open(filepath:string(), "rb")
		
		--print(endless)
		for tag, op in pairs(readops) do
			f:seek("set")
			-- luacheck: ignore endless
			local endless = f:read(1)
			local c = f:read(#tag)
			if c == tag then
				f:close()
				return op
			end
		end
		
		f:close()
	end

	local readops = {
		["ozz-animation"] = function (filename)
			local animodule = require "hierarchy.animation"
			return animodule.new_ani(filename)
		end,
		["ozz-skeleton"] = function(filename)
			local hiemodule = require "hierarchy"
			return hiemodule.build(filename)
		end,
		["ozz-sample-Mesh"] = function(filename)
			local animodule = require "hierarchy.animation"
			return animodule.new_ozzmesh(filename)
		end,
	}

	local readop = find_tagop(fn, readops)
	if readop then
		return {
			handle = readop(vfs.realpath(fn:string()))
		}
	end
	error("not support type")
	return nil
end