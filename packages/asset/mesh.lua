local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "asset"
local ext_meshbin 	= require "ext_meshbin"

local meshcore		= ecs.clibs "render.mesh"

local imesh = ecs.interface "imesh"
function imesh.create_vb(vb)
	return ext_meshbin.proxy_vb(vb)
end

function imesh.create_ib(ib)
	return ext_meshbin.proxy_ib(ib)
end

imesh.init_mesh = ext_meshbin.init

local ms = ecs.system "mesh_system"

function ms:component_init()
	for e in w:select "INIT mesh:update" do
		e.mesh = assetmgr.resource(e.mesh)
	end
end

function ms:entity_init()
	for e in w:select "INIT mesh:in render_object:in id:in" do
		e.render_object.mesh = meshcore.mesh(e.mesh)
	end

	for e in w:select "INIT simplemesh:in render_object:in id:in owned_mesh_buffer?out" do
		local sm = e.simplemesh
		e.render_object.mesh = meshcore.mesh(sm)
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
