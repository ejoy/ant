local utility = require "model.utility"

local prefab = {
	[1] = {
		policy = {
			"ant.animation|animation",
		},
		data = {
			animation = "$path animations/animation.ozz",
		},
		tag = { "animation" },
	}
}

local function conv(data)
	return data
end

return function (status)
	utility.save_txt_file(status, "animation.prefab", prefab, conv)
end
