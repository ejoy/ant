local ecs = ...
local world = ecs.world

-- luacheck: ignore param
-- ecs.import "timer"
-- ecs.import "animation.ik"

local ani = ecs.component_struct "animation" {
	ani_list = {
		type = "userdata",
		default = {
			--[[
			weight = 0.0,
			handle = load from asset lib,
			ref_path = respath,				
			sampling_cache = create from animation c module,
			weighttype = "full" or "partical", to animaiton system how to blend
			]]
		},
		save = function(v, param)
		end,
		load = function(v, param)
		end,
	},
}

function ani:init()
	self.ratio = 0
	self.aniresult = nil
end

-- separate animation and skeleton to 2 component, 
-- skeleton component will corresponding to some system that do not need animation
local ske = ecs.component_struct "skeleton" {
	ref_path = {
		type = "userdata",
		default = "",
		save = function (v, param)
			assert(false, "not implement skeleton save")
		end,
		load = function (v, param)
			assert(false, "not implement skeleton load")
		end
	},	
}

function ske:init()
	self.handle = nil
end


local anisystem = ecs.system "animation_system"
anisystem.singleton "timer"

local ani_module = require "hierarchy.animation"
local ik_module = require "hierarchy.ik"

local ms = import_package("math").stack

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

