return function(filename)
	local function find_tag(tags)
		local f = io.open(filename, "rb")
		
		--print(endless)
		for _, tag in ipairs(tags) do
			f:seek("set")
			-- luacheck: ignore endless
			local endless = f:read(1)
			local c = f:read(#tag)
			if c == tag then
				f:close()
				return tag
			end
		end
		
		f:close()
	end

	local tag = find_tag({"ozz-animation", "ozz-skeleton"})

	if tag == "ozz-animation" then
		local animodule = require "hierarchy.animation"
		return animodule.new_ani(filename)
	elseif  tag == "ozz-skeleton" then
		local hiemodule = require "hierarchy"
		return hiemodule.build(filename)
	end

	error("not support type")
	return nil
end