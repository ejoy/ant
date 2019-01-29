local ecs = ...
local world = ecs.world
local schema = world.schema

local asset = import_package "ant.asset"

schema:type "animation_content"
	.weight "real"
	.weighttype "string" ("full")
	.ref_path "resource"
	.name "string"
	.scale "real" (1)	
	.looptime "int" (1)

local animation_content = ecs.component "animation_content"

local function calc_ratio(current, ani)
	local handle = assert(ani.handle)
	local duration = handle:duration()
	local localtime = (current - ani.starttime) * ani.scale
	local frametime = localtime - duration * ani.looptime
	frametime = math.min(duration, frametime)
	return frametime / duration
end

function animation_content:init()
	self.starttime = 0
	self.ratio = 0	
	return self
end

function animation_content:save()
	local name = self.name
	if name == nil or name == "" then
		local filename = self.ref_path.filename
		self.name = filename:filename()
	end
end

function animation_content:load()
	self.handle = asset.load(self.ref_path.package, self.ref_path.filename)
end

schema:type "animation"
	.anilist "animation_content[]"
	.blendtype "blend"

local ani = ecs.component "animation"
	  
function ani:init()	
	self.aniresult = nil
	self.pose = {
		define = {}
	}
	return self
end

-- separate animation and skeleton to 2 component, 
-- skeleton component will corresponding to some system that do not need animation
schema:type "skeleton"
	.ref_path "resource"

local skeleton = ecs.component "skeleton"

function skeleton:load()
	self.handle = asset.load(self.ref_path.package, self.ref_path.filename)
end


local anisystem = ecs.system "animation_system"
anisystem.singleton "timer"

local ani_module = require "hierarchy.animation"
local ik_module = require "hierarchy.ik"

local ms = import_package "ant.math".stack

local function deep_copy(t)
	local typet = type(t)
	if typet == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

function anisystem:update()
	local timer = self.timer
	local currenttime = timer.current

	for _, eid in world:each("animation") do
		local e = world[eid]
		local skecomp = assert(e.skeleton)

		local ske = assert(skecomp.assetinfo).handle
		local anicomp = assert(e.animation)

		local ikcomp = e.ik
		if ikcomp and ikcomp.enable then
			local mat = ms({type="srt", s=e.scale, r=e.rotation, t=e.position}, "m")

			local t = deep_copy(ikcomp)
			t.target = ms(assert(t.target), "m")
			t.pole_vector = ms(assert(t.pole_vector), "m")
			t.mid_axis = ms(assert(t.mid_axis), "m")

			ik_module.do_ik(mat, ske, t, anicomp.aniresult)
		else
			-- local anilist = assert(anicomp.anilist)
			-- if #anilist > 0 then
			-- 	for _, a in ipairs(anilist) do
			-- 		assert(a.starttime and a.starttime ~= 0)
			-- 		a.ratio = calc_ratio(timer.current, a)
			-- 	end
			-- 	ani_module.motion(ske, anilist, anicomp.blendtype, anicomp.aniresult)
			-- end

			local anipose = anicomp.pose
			local define = anipose.define
			local transmit = anipose.transmit

			local anilist_ref = anicomp.anilist
			local function fetch_anilist(pose)
				local anilist = {}
				for _, aniref in ipairs(pose.anilist) do
					local ani = assert(anilist_ref[aniref.idx])
					ani.ratio = calc_ratio(currenttime, ani)
					ani.weight = aniref.weight
					anilist[#anilist] = ani
				end
				return anilist
			end

			local srcanilist = fetch_anilist(define)
			if transmit then
				local targetanilist = fetch_anilist(transmit.targetpose)
				local srcbindpose = ani_module.new_bind_pose()
				local targetbindpose = ani_module.new_bind_pose()

				ani_module.blend_animations(ske, srcanilist, anicomp.blendtype, srcbindpose)
				ani_module.blend_animations(ske, targetanilist, anicomp.blendtype, targetbindpose)

				local finalbindpose = ani_module.new_bind_pose()
				ani_module.blend_bind_poses(ske, {
					{pose=srcbindpose, weight=assert(transmit.source_weight)}, 
					{pose=targetbindpose, weight=assert(transmit.target_weight)}
				}, anicomp.blendtype, finalbindpose)
				ani_module.transform(ske, finalbindpose, anicomp.aniresult)
			else
				ani_module.motion(ske, srcanilist, anicomp.blendtype, anicomp.aniresult)
			end
			
		end		
	end
end

