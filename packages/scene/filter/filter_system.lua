local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.scene|ientity_state"

local function update_bounding(rc, e)
	local worldmat = rc.worldmat
	local mesh = e.mesh
	if worldmat == nil or mesh == nil or mesh.bounding == nil then
		rc.aabb = nil
	else
		rc.aabb = math3d.aabb_transform(rc.worldmat, mesh.bounding.aabb)
	end
end

local function update_transform(eid)
	local e = world[eid]
	local rc = e._rendercache
	if rc.srt == nil and e.parent == nil then
		return
	end

	rc.worldmat = rc.srt and math3d.matrix(rc.srt) or nil

	if e.parent then
		-- combine parent transform
		if e.lock_target == nil then
			local pe = world[e.parent]
			-- need apply before tr.worldmat
			local bs_idx = e._bind_slot_idx
			if bs_idx then
				local t = pe.pose_result:joint(bs_idx)
				rc.worldmat = math3d.mul(t, rc.worldmat)
			end
			local p_rc = pe._rendercache
			if p_rc.worldmat then
				rc.worldmat = rc.worldmat and math3d.mul(p_rc.worldmat, rc.worldmat) or math3d.matrix(p_rc.worldmat)
			end
		end
	end

	update_bounding(rc, e)
end

function filter_system:filter_render_items()
	for _, eid in ipairs(iss.scenequeue()) do
		update_transform(eid)
	end
end