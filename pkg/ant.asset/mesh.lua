local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "main"
local ext_meshbin 	= require "ext_meshbin"

local imesh = {}

imesh.init_mesh = ext_meshbin.init

function imesh.build_meshes(files)
	local function init_buffer() return {start=0, num=0, memory = {list={}, nil, 1, 0} } end
	local vb, vb2 = init_buffer(), init_buffer()
	local ib = init_buffer()
	local vbnums, ibnums = {}, {}
	for _, mf in ipairs(files) do
		local mesh = assetmgr.resource(mf)

		local function update_buffer(b, ob)
			if b then
				local om 	= ob.memory
				local str 	= b.str
				om.list[#om.list+1] = str
				om[3]		= om[3] + #str

				ob.num 		= ob.num + b.num
				ob.declname = b.declname
				ob.flag		= b.flag
			end
		end

		update_buffer(mesh.vb, vb)
		update_buffer(mesh.vb2,vb2)
		update_buffer(mesh.ib, ib)

		vbnums[#vbnums+1] = mesh.vb.num
		ibnums[#ibnums+1] = mesh.ib.num
	end

	local function tobuffer(b)
		if b.num > 0 then
			b.memory[1] = table.concat(b.memory.list, "")
			b.memory.list = nil
			return b
		end
	end

	return ext_meshbin.init{
		vb	= tobuffer(vb),
		vb2	= tobuffer(vb2),
		ib  = tobuffer(ib),
	}, vbnums, ibnums
end

--TODO: we should move this system to render package, it need sync data to render_object, but asset package should not depend on render package
local ms = ecs.system "mesh_system"

function ms:component_init()
	for e in w:select "INIT mesh:update" do
		e.mesh = assetmgr.resource(e.mesh)
	end
end

function ms:entity_remove()
	for e in w:select "REMOVED owned_mesh_buffer simplemesh:in" do
		ext_meshbin.delete(e.simplemesh)
	end
end

return imesh
