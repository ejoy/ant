local ecs = ...
local world = ecs.world
local fs_util = require "filesystem.util"
local component_util = require "render.components.util"
local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "iup_message"

function add_entity_sys:init()
    local ms = self.math_stack

    do
        local bunny_eid = world:new_entity("position", "rotation", "scale", 
			"can_render", "mesh", "material",
			"name", "serialize",
            "can_select")
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file        
        ms(bunny.scale.v, {0.2, 0.2, 0.2, 0}, "=")
        ms(bunny.position.v, {0, 0, 3, 1}, "=")
		ms(bunny.rotation.v, {0, -60, 0, 0}, "=")

		bunny.mesh.path = "bunny.mesh"
		component_util.load_mesh(bunny)
		
		bunny.material.content[1] = {path = "bunny.material", properties = {}}
		component_util.load_material(bunny)
	end
	
    local function create_entity(name, meshfile, materialfile)
        local eid = world:new_entity("rotation", "position", "scale", 
		"mesh", "material", 
		"name", "serialize",
		"can_select", "can_render")
		
        local entity = world[eid]
        entity.name.n = name
        
        ms(entity.scale.v, {1, 1, 1}, "=")
        ms(entity.position.v, {0, 0, 0, 1}, "=") 
        ms(entity.rotation.v, {0, 0, 0}, "=")

		entity.mesh.path = meshfile
		component_util.load_mesh(entity)
		entity.material.content[1] = {path=materialfile, properties={}}
		component_util.load_material(entity)
        return eid
    end

    do
        local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
            "scale", "rotation", "position", 
            "name", "serialize")
        local hierarchy_e = world[hierarchy_eid]

        hierarchy_e.name.n = "hierarchy_test"

        ms(hierarchy_e.scale.v, {1, 1, 1}, "=")
        ms(hierarchy_e.rotation.v, {0, 60, 0}, "=")
        ms(hierarchy_e.position.v, {10, 0, 0, 1}, "=")

        local hierarchy = hierarchy_e.editable_hierarchy.root

        hierarchy[1] = {
            name = "h1_cube",
            transform = {
                t = {3, 4, 5},
                s = {0.01, 0.01, 0.01},
            }
        }

        hierarchy[2] = {
            name = "h1_sphere",
            transform = {
                t = {1, 2, 3},
                s = {0.01, 0.01, 0.01},
            }
        }

        hierarchy[1][1] = {
            name = "h1_h1_cube",
            transform = {
                t = {3, 3, 3},
                s = {0.01, 0.01, 0.01},
            }
		}
		
		local material_path = "mem://hierarchy.material"
		fs_util.write_to_file(material_path, [[
			shader = {
				vs = "vs_mesh",
				fs = "fs_mesh",
			}
			state = "default.state"
			properties = {
				u_time = {name="u_time", type="v4", default={1, 0, 0, 1}}
			}
		]])

        local cube_eid = create_entity("h1_cube", "cube.mesh", material_path)
        local cube_eid_1 = create_entity("h1_h1_cube", "cube.mesh", material_path)
        do
            local e = world[cube_eid_1] 
            ms(e.scale.v, {0.5, 0.5, 0.5}, "=")
        end

        local sphere_eid = create_entity("h1_sphere", "sphere.mesh", material_path)
        local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)

        name_mapper.h1_cube     = cube_eid
        name_mapper.h1_h1_cube  = cube_eid_1
		name_mapper.h1_sphere   = sphere_eid
		
		world:change_component(hierarchy_eid, "rebuild_hierarchy")
		world:notify()
    end
end