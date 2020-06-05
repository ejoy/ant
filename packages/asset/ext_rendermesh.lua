local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"
local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local function build_skin(skin)
	if skin then
		local ibm = skin.inverse_bind_matrices
		return {
			inverse_bind_pose = animodule.new_bind_pose(ibm.num, ibm.value),
			joint_remap = animodule.new_joint_remap(skin.joints)
		}
	end
end

return {
    loader = function (group)
		local vb = group.vb
		local handles = {}
		for _, value in ipairs(vb.values) do
			if value.dynamic then
				handles[#handles+1] = {
					handle = bgfx.create_dynamic_vertex_buffer(value.dynamic, declmgr.get(value.declname).handle, "a"),
					updatedata = animodule.new_aligned_memory(value.dynamic),
				}
			else
				local start_bytes = value.start
				local end_bytes = start_bytes + value.num - 1
				handles[#handles+1] = {
					handle = bgfx.create_vertex_buffer({"!", value.value, start_bytes, end_bytes}, declmgr.get(value.declname).handle),
					vertex_data = value,
				}
			end
		end
		local meshgroup = {
			bounding = group.bounding,
			skin = build_skin(group.skin),
			vb = {
				start 	= vb.start,
				num 	= vb.num,
				handles = handles,
			}
		}
	
		local ib = group.ib
		if ib then
			local v = ib.value
			if v.dynamic then
				meshgroup.ib = {
					start = ib.start,
					num = ib.num,
					handle = bgfx.create_dynamic_index_buffer(v.dynamic, "a"),
					updatedata = animodule.new_aligned_memory(v.dynamic),
				}
			else
				local startbytes = v.start
				local endbytes = startbytes+v.num-1
				meshgroup.ib = {
					start = ib.start,
					num = ib.num,
					handle = bgfx.create_index_buffer({v.value, startbytes, endbytes}, v.flag),
				}
			end
		end
	
		return meshgroup
    end,
    unloader = function (res)
    end,
}
