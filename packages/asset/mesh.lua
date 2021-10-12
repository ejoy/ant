local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "asset"
local ext_meshbin 	= require "ext_meshbin"

local function create_rendermesh(mesh)
	if mesh then
		local handles = {}
		local vb = {
			start   = mesh.vb.start,
			num     = mesh.vb.num,
			handles = handles,
		}
		for _, v in ipairs(mesh.vb) do
			handles[#handles+1] = v.handle
		end
		local ib
		if mesh.ib then
			ib = {
				start	= mesh.ib.start,
				num 	= mesh.ib.num,
				handle	= mesh.ib.handle,
			}
		end

		return vb, ib
	end
end

local imesh = ecs.interface "imesh"
function imesh.create_vb(vb)
	return ext_meshbin.proxy_vb(vb)
end

function imesh.create_ib(ib)
	return ext_meshbin.proxy_ib(ib)
end

function imesh.init_mesh(mesh, owned_mesh_buffer)
	mesh.owned_mesh_buffer = owned_mesh_buffer
	return ext_meshbin.init(mesh)
end

local ms = ecs.system "mesh_system"

function ms:entity_init()
	for e in w:select "INIT mesh:update render_object:in" do
		e.mesh = assetmgr.resource(e.mesh)
		local ro = e.render_object
		ro.vb, ro.ib = create_rendermesh(e.mesh)
	end

	for e in w:select "INIT simplemesh:in render_object:in owned_mesh_buffer?out" do
		local sm = e.simplemesh
		local ro = e.render_object
		ro.vb, ro.ib = create_rendermesh(sm)
		e.owned_mesh_buffer = sm.owned_mesh_buffer
	end
end

function ms:end_frame()
	for e in w:select "REMOVED owned_mesh_buffer render_object:in simplemesh:in" do
		if e.owned_mesh_buffer then
			ext_meshbin.delete(e.simplemesh)
		end
	end
end