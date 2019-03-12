local ecs = ...
local world = ecs.world


local geometry = import_package "ant.geometry"
local geodrawer = geometry.drawer

local renderbonesys = ecs.system "renderbone_system"
renderbonesys.singleton "debug_object"
renderbonesys.dependby "debug_draw"

local ms = import_package "ant.math".stack

local function draw_skeleton(sample)
	local ske = sample.skeleton
	if ske then
		local desc = {vb={}, ib = {}}
		local worldtrans = nil
		local anicomp = sample.animation
		geodrawer.draw_skeleton(assert(ske.assetinfo.handle), anicomp and anicomp.aniresult or nil, 0xfff0f0f0, worldtrans, desc)
		return desc
	end
end

local default_sphere = {center={0, 0, 0}, radius=1, tessellation=2}
local function draw_sphere(m43)
	local mat = ms:matrix(
		m43[1], m43[2], m43[3], 0,
		m43[4], m43[5], m43[6], 0,
		m43[7], m43[8], m43[9], 0,
		--0, 0, 0, 1)
		m43[10] * 0.01, m43[11] * 0.01, m43[12] * 0.01, 1)

	print("translate:", m43[10], m43[11], m43[12])
	
	local desc = {vb={}, ib={}, primitives={}}
	geodrawer.draw_sphere(default_sphere, 0xffffff00, mat, desc)
	return desc
end

local function append_array(from, to)				
	table.move(from, 1, #from, #to+1, to)
end

local function append_desc(buffer, desc)
	local voffset = #buffer.vb
	local ioffset = #buffer.ib
	append_array(desc.vb, buffer.vb)
	append_array(desc.ib, buffer.ib)
	if desc.primitives then		
		local primitives = {}
		for _, prim in ipairs(desc.primitives) do
			primitives[#primitives+1] = {
				startVertex=voffset+prim.startVertex, 
				numVertices=prim.numVertices, 
				startIndex=ioffset+prim.startIndex, 
				numIndices=prim.numIndices
			}
		end		
		append_array(primitives, buffer.primitives)
	end
end

local cache

function renderbonesys:update()
	local descbuffer = self.debug_object.renderobjs.wireframe.desc

	local sample = world:first_entity("sampleobj")
	if sample then
		local dbgprim = sample.debug_skeleton
		if dbgprim then
			local desc = draw_skeleton(sample)
			if desc then
				append_desc(descbuffer, desc)
			end
		end	
	end
end