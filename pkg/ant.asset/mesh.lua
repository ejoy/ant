local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "main"
local ext_meshbin 	= require "ext_meshbin"

local imesh = {}

imesh.init_mesh = ext_meshbin.init

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
