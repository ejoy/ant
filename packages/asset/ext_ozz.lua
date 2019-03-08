local fs = require "filesystem"

return function(filename)
	local function find_tagop(filepath, readops)
		local f = fs.open(filepath, "rb")
		
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
		["ozz-raw_skeleton"] = function (filename)
			local hiemodule = require "hierarchy"
			local editable_hie = hiemodule.new()
			hiemodule.load(editable_hie, filename)
			return editable_hie
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

	local readop = find_tagop(filename, readops)
	if readop then
		return {
			handle = readop(filename:localpath():string())
		}
	end
	error("not support type")
	return nil
end