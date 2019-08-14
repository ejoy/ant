local fs = require "filesystem"
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

return {
	loader = function(filename)
		local readops = {
			["ozz-animation"] = function (fn)
				local animodule = require "hierarchy.animation"
				return animodule.new_ani(fn)
			end,
			["ozz-raw_skeleton"] = function (fn)
				local hiemodule = require "hierarchy"
				local editable_hie = hiemodule.new()
				editable_hie:load(fn)
				return editable_hie
			end,
			["ozz-skeleton"] = function(fn)
				local hiemodule = require "hierarchy"
				return hiemodule.build(fn)
			end,
			["ozz-sample-Mesh"] = function(fn)
				local animodule = require "hierarchy.animation"
				return animodule.new_ozzmesh(fn)
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
	end,

	unloader = function(res)
		res.handle = nil
	end
}