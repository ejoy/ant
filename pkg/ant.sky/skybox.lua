local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local geopkg 	= import_package "ant.geometry"
local geo 		= geopkg.geometry

local ientity	= ecs.require "ant.render|components.entity"
local skybox_sys = ecs.system "skybox_system"

function skybox_sys:component_init()
	for e in w:select "INIT skybox:in simplemesh:out mesh_result:out owned_mesh_buffer?out" do
		local vb, ib = geo.box(1, true, false)
		local m = ientity.create_mesh({"p3", vb}, ib)
		e.simplemesh = m
		e.mesh_result = m
		e.owned_mesh_buffer = true
	end
end