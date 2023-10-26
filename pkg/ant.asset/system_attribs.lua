local bgfx = require "bgfx"
local sa	= import_package "ant.render.core".system_attribs
local UNIFORM_TYPES<const> = {
	v = "v4", m = "m4"
}

local function init_attrib(n, a, tm)
	if a.type == "u" or a.type == "t" then
		local c = 1
		local ut
		if a.stage == nil then
			local utype = assert(a.utype)
			local sn
			ut, sn = utype:match "([vm])(%d+)"
			if ut == nil or sn == nil then
				error("Invalid utype " .. utype)
			end
			ut = assert(UNIFORM_TYPES[ut], "Invalid uniform type")
			c = assert(tonumber(sn), "Invalid number")
		else
			ut = "s"
			a.value = tm.default_textureid(a.stype) or error (("Invalid sampler type:%s"):format(a.stype))
		end
		a.handle = bgfx.create_uniform(n, ut, c)
	end
end

return {
	get	= function (n)
		return sa[n]
	end,
	init = function (texture_mgr, MA)
		for n, a in pairs(sa) do
			init_attrib(n, a, texture_mgr)
		end

		MA.init(sa)
	end
}