local Util = {}
local mathpkg   = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local geopkg    = import_package "ant.geometry"
local fs        = require "filesystem"
local assetmgr = import_package "ant.asset".mgr

local function line(start_pos, end_pos, color)  
    local vb, ib = {}, {}       
    local function add_vertex(pos, clr)
        local x,y,z = table.unpack(pos)
        log.trace(x,y,z,clr)
        table.insert(vb, {x,y,z, clr})          
    end

    local function add_line(p1, p2, color)
        add_vertex(p1, color)
        add_vertex(p2, color)
        -- call 2 times
        table.insert(ib, #ib)
        table.insert(ib, #ib)
    end

    -- center lines
    add_line(start_pos, end_pos, color)

    return vb, ib
end


local function create_line_entity(world, name, start_pos,end_pos,color,view_tag,parent,dir)
    local util  = import_package "ant.render".components
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

    local gridid = world:create_entity {
        transform = mu.identity_transform(),
        rendermesh = {},
        material = util.assign_material(fs.path "/pkg/ant.resources" / "materials" / "gizmo_line.material"),
        name = name,
        can_render = true,
        main_view = true,
        can_select = true,
        gizmo_object = {dir = dir},
        hierarchy_visible = true,
    }
    local grid = world[gridid]
    grid.transform.parent = parent
    if view_tag then world:add_component(gridid, view_tag, true) end
    local vb, ib = line(start_pos, end_pos, color)
    local gvb = {"fffd"}
    for _, v in ipairs(vb) do
        for _, vv in ipairs(v) do
            table.insert(gvb, vv)
        end
    end

    local num_vertices = #vb
    local num_indices = #ib

    local reskey = fs.path(string.format("//meshres/%s.mesh",name))
    grid.rendermesh.reskey = assetmgr.register_resource(reskey,util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
    return gridid
end

local function create_cone_entity(world, color, size,rot,pos, name,parent,dir)
    local computil  = import_package "ant.render".components
    return world:create_entity {
        transform = {
            s = size or {1, 1, 1},
            r = rot or {0, 0, 0, 0},
            t = pos or {0, 0, 0, 1},
            parent = parent,
        },
        rendermesh = {},
        mesh = {ref_path = fs.path "/pkg/ant.resources/depiction/meshes/cone.mesh"},
        material = computil.assign_material(
                fs.path "/pkg/ant.resources/depiction/materials/gizmo_singlecolor.material",
                {uniforms = {u_color = {type="v4", name="u_color", value=color}},}),
        can_render = true,
        --can_cast = true,
        main_view = true,
        name = name,
        can_select = true,
        gizmo_object = {dir=dir},
        hierarchy_visible = true,

    }
end

local function create_box_entity(world, color, size, pos, name,parent,dir)
    local computil  = import_package "ant.render".components
    return world:create_entity {
        transform = {
            s = size or {1, 1, 1},
            r = {0, 0, 0, 0},
            t = pos or {0, 0, 0, 1},
            parent = parent,
        },
        rendermesh = {},
        mesh = {ref_path = fs.path "/pkg/ant.resources/depiction/meshes/cube.mesh"},
        material = computil.assign_material(
                fs.path "/pkg/ant.resources/depiction/materials/gizmo_singlecolor.material",
                {uniforms = {u_color = {type="v4", name="u_color", value=color}},}),
        can_render = true,
        --can_cast = true,
        main_view = true,
        name = name,
        can_select = true,
        gizmo_object = {dir=dir},
        hierarchy_visible = true,

    }
end

-- return {
--     eid=?,
--     position = {
--         eid=?,
--         line_x,line_y,line_z = ???,
--         cone_x,cone_y,cone_z = ???,
--     },
--     scale = {
--         eid=?,
--         line_x,line_y,line_z = ???,
--         box_x,box_y,box_z = ???,
--     },
--     rotation = {
--         ...
--     }
-- }
function Util.create_gizmo(world)
    local seriazlizeutil = import_package "ant.serialize"
    local function create_gizmo_object(name,parent)
        local trans = mu.srt()
        trans.parent = parent
        local eid = world:create_entity {
            transform = trans,
            name = name,
            hierarchy = {},
            main_view = true,
            -- serialize = seriazlizeutil.create(),
            hierarchy_visible = true,
            gizmo_object = {},
            -- can_select = true,
        }
        return eid
    end
    local root = create_gizmo_object("gizmo",nil)
    local result = {eid = root}

    --
    do
        local line_length = 1.3
        local position = {}
        result.position = position
        position.line_length = line_length
        local parent = create_gizmo_object("position",root)
        position.eid = parent
        position.line_x = create_line_entity(world,"line_x",{0,0,0},{line_length,0,0},0xff0000ff,"main_view",parent,"x")
        position.cone_x = create_cone_entity(world,{1,0,0,1},{0.1,0.13,0.1},{0,0,-0.5*math.pi,0}, {line_length,0,0}, "cone_x",parent,"x")
        position.line_y = create_line_entity(world,"line_y",{0,0,0},{0,line_length,0},0xff00ff00,"main_view",parent,"y")
        position.cone_y = create_cone_entity(world,{0,1,0,1},{0.1,0.13,0.1},{0,0,0,0},{0,line_length,0}, "cone_y",parent,"y")
        position.line_z = create_line_entity(world,"line_z",{0,0,0},{0,0,line_length},0xffff0000,"main_view",parent,"z")
        position.cone_z = create_cone_entity(world,{0,0,1,1},{0.1,0.13,0.1},{0.5*math.pi,0,0,0}, {0,0,line_length}, "cone_z",parent,"z")
        position.center = create_box_entity(world,{1,1,1,1},{0.15,0.15,0.15}, {0,0,0}, "box_o",parent)
    end

    do
        local line_length = 1.3
        local scale = {}
        result.scale = scale
        scale.line_length = line_length
        local parent = create_gizmo_object("scale",root)
        scale.eid = parent
        scale.line_x = create_line_entity(world,"line_x",{0,0,0},{line_length,0,0},0xff0000ff,"main_view",parent,"x")
        scale.box_x = create_box_entity(world,{1,0,0,1},{0.15,0.15,0.15}, {line_length,0,0}, "box_x",parent,"x")
        scale.line_y = create_line_entity(world,"line_y",{0,0,0},{0,line_length,0},0xff00ff00,"main_view",parent,"y")
        scale.box_y = create_box_entity(world,{0,1,0,1},{0.15,0.15,0.15},{0,line_length,0}, "box_y",parent,"y")
        scale.line_z = create_line_entity(world,"line_z",{0,0,0},{0,0,line_length},0xffff0000,"main_view",parent,"z")
        scale.box_z = create_box_entity(world,{0,0,1,1},{0.15,0.15,0.15}, {0,0,line_length}, "box_z",parent,"z")
        scale.center = create_box_entity(world,{1,1,1,1},{0.18,0.18,0.18}, {0,0,0}, "box_o",parent)
    end
    do
        local rotation = {}
        result.rotation = rotation
        local parent = create_gizmo_object("rotation",root)
        rotation.eid = parent
        rotation.line_x = create_line_entity(world,"line_x",{0,0,0},{1,0,0},0xff0000ff,"main_view",parent,"x")
        rotation.box_x = create_box_entity(world,{1,0,0,1},{0.18,0.18,0.18}, {1,0,0}, "box_x",parent,"x")
        rotation.line_y = create_line_entity(world,"line_y",{0,0,0},{0,1,0},0xff00ff00,"main_view",parent,"y")
        rotation.box_y = create_box_entity(world,{0,1,0,1},{0.18,0.18,0.18},{0,1,0}, "box_y",parent,"y")
        rotation.line_z = create_line_entity(world,"line_z",{0,0,0},{0,0,1},0xffff0000,"main_view",parent,"z")
        rotation.box_z = create_box_entity(world,{0,0,1,1},{0.18,0.18,0.18}, {0,0,1}, "box_z",parent,"z")
        rotation.center = create_box_entity(world,{1,1,1,1},{0.12,0.12,0.12}, {0,0,0}, "box_o",parent)
    end
    return result
end

return Util