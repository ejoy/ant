local util = {}; util.__index = util

local mu = require "math.util"

local function update_child_srt(ms, e, srt, node)
    local rot = ms({type="q", table.unpack(node.r)}, "eT")
    rot[1], rot[2] = rot[2], rot[1]

	local localsrt = mu.srt(ms, node.s, rot, node.t);
	local s, r, t = ms(localsrt, srt, "*~PPP");
	--[[
		local r_srt = assert(e.relative_srt)
		local s, r, t = ms(localsrt, relative_srt, "*~PPP")
	]]
	
	ms(e.scale.v, s, "=", e.rotation.v, r, "=", e.position.v, t, "=")
end

function util.update_hierarchy_entiy(ms, world, h_entity)
	local hierarchy = assert(h_entity.hierarchy)
	
	local rootsrt = mu.srt_from_entity(ms, h_entity)
	local builddata = hierarchy.builddata

	local mapper = h_entity.hierarchy_name_mapper.v
	for _, node in ipairs(builddata) do
		local name = node.name
		local c_eid = mapper[name]
		local c_entity = world[c_eid]

		if c_entity then
			update_child_srt(ms, c_entity, rootsrt, node)
		else
			error(string.format("not found entity by hierarchy name mapper, name is : %s", name))
		end
	end
end

return util