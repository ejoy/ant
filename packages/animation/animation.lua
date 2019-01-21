local ecs = ...
local world = ecs.world
local schema = world.schema

local asset = import_package "ant.asset"

schema:type "animation_content"
	.weight "real"
	.weighttype "string" ("full")
	.ref_path "resource"

local animation_content = ecs.component "animation_content"

function animation_content:load()
	self.handle = asset.load(self.ref_path.package, self.ref_path.filename)
end

schema:type "animation"
	.anilist "animation_content[]"

local ani = ecs.component "animation"
	  
function ani:init()
	self.ratio = 0
	self.aniresult = nil
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
			local anilist = assert(anicomp.anilist)
			if #anilist > 0 then
				ani_module.motion(ske, anicomp.ratio, anilist, "blend", anicomp.aniresult)
			end
		end		
	end
end

