local aio = import_package "ant.io"
local ozz = require "ozz"

local function loader(filename)
	local h, t = ozz.load(aio.readall(filename))
	local r = {
		_handle		= h,
		type		= t,
		filename	= filename,
	}

	--TODO: need remove
	if t == "ozz-animation" then
		local scale = 1     -- TODO
		local looptimes = 0 -- TODO
		r._sampling_context = ozz.new_sampling_context()
 		r._duration 		= r._handle:duration() * 1000. / scale
 		r._max_ratio 		= looptimes > 0 and looptimes or math.maxinteger
	end
	return r
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
