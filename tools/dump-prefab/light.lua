local serialize = import_package "ant.serialize"
local sha1 = require "sha1"

local function init_light(e)
    local t = e.light_type
	local range = e.range
	local l = {
        light_type  = t,
		color		= e.color or {1, 1, 1, 1},

		intensity	= e.intensity or 2,
		make_shadow	= e.make_shadow or false,
		motion_type = e.motion_type or "dynamic",
        range       = math.maxinteger,
        inner_cutoff= 0,
        outter_cutoff= 0,
        angular_radius= 0,
	}

	if t == "point" or t == "spot" then
		if range == nil then
			error("point/spot light need range defined!")
		end
		l.range = range
		if t == "spot" then
			local i_r, o_r = e.inner_radian, e.outter_radian
			if i_r == nil or o_r == nil then
				error("spot light need 'inner_radian' and 'outter_radian' defined!")
			end

			if i_r > o_r then
				error(("invalid 'inner_radian' > 'outter_radian':%d, %d"):format(i_r, o_r))
			end
			l.inner_cutoff = math.cos(l.inner_radian * 0.5)
			l.outter_cutoff = math.cos(l.outter_radian * 0.5)
		end
    elseif t == "area" then
        l.angular_radius = e.angular_radius or 0.27
	end
	return l
end

return {
    load = function (l)
        local light = init_light(l)
        local bin = serialize.pack(light)
        return {
            name = "light-" .. sha1(bin),
            value = light,
        }
    end,
}