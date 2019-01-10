local ecs = ...
local world = ecs.world


local geometry = import_package "geometry"
local geodrawer = geometry.drawer
local geoutil = geometry.util

local renderbonesys = ecs.system "renderbone_system"
renderbonesys.singleton "debug_object"
renderbonesys.dependby "debug_draw"

local function draw_skeleton(sample)
	local ske = sample.skeleton
	if ske then
		local desc = {vb={}, ib = {}}
		local worldtrans = nil
		if sample.animation then			
			local bones = geoutil.generate_bones(ske.assetinfo.handle)
			local aniresult = assert(sample.animation.aniresult)
			local numjoints = aniresult:count()
			local joints = {}
			for i=1, numjoints do
				table.insert(joints, aniresult:joint(i-1))
			end
			geodrawer.draw_bones(bones, joints, 0xfff0f0f0, worldtrans, desc)
		else
			geodrawer.draw_skeleton(assert(ske.assetinfo.handle), 0xfff0f0f0, worldtrans, desc)
		end
		return desc
	end
end

function renderbonesys:update()
	local sample = world:first_entity("sampleobj")
	if sample then
		local dbgprim = sample.debug_skeleton
		if dbgprim then
			local desc = draw_skeleton(sample)
			if desc then
				local descbuffer = self.debug_object.renderobjs.wireframe.desc
				local function append_array(from, to)				
					table.move(from, 1, #from, #to+1, to)
				end

				append_array(desc.vb, descbuffer.vb)
				append_array(desc.ib, descbuffer.ib)
				if desc.primitives then
					append_array(desc.primitives, descbuffer.primitives)
				end
			end
			
		end	
	end
end