return function(filename)
	local function find_tag(tags)
		local f = io.open(filename, "rb")

		for _, tag in ipairs(tags) do
			f:seek("set")
			if f:read(#tag) == tag then
				f:close()
				return tag
			end
		end
		
		f:close()
	end

	local tag = find_tag({"ozz-animation", "ozz-skeleton"})

	if tag == "ozz-animation" then
		local animodule = require "hierarchy.animation"
		return animodule.new_animation(filename)
	elseif  tag == "ozz-skeleton" then
		local hiemodule = require "hierarchy"
		return hiemodule.load(filename)
	end

	error("not support type")
	return nil
end