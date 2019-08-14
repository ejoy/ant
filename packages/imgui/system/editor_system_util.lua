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


local function create_line_entity(world, name, start_pos,end_pos,color,view_tag,parent)
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
        gizmo_object = true,
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

local function create_cone_entity(world, color, size,rot,pos, name,parent)
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
        gizmo_object = true,
        hierarchy_visible = true,

    }
end

local function create_box_entity(world, color, size, pos, name,parent)
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
        gizmo_object = true,
        hierarchy_visible = true,

    }
end

function Util.create_position_gizmo(world)
    local seriazlizeutil = import_package "ant.serialize"
    local parent = world:create_entity {
            transform = mu.srt(),
            name = 'scale_axis',
            hierarchy = {},
            main_view = true,
            -- serialize = seriazlizeutil.create(),
            hierarchy_visible = true,
            gizmo_object = true,
            -- can_select = true,
        }
    local y_add = 0
    local line_x = create_line_entity(world,"line_x",{0,0+y_add,0},{1,0+y_add,0},0xff0000ff,"main_view",parent)
    local cone_x = create_cone_entity(world,{1,0,0,1},{0.06,0.1,0.06},{0,0,-0.5*math.pi,0}, {1,0+y_add,0}, "cone_x",parent)
    local line_y = create_line_entity(world,"line_y",{0,0+y_add,0},{0,1+y_add,0},0xff00ff00,"main_view",parent)
    local cone_y = create_cone_entity(world,{0,1,0,1},{0.06,0.1,0.06},{0,0,0,0},{0,1+y_add,0}, "cone_y",parent)
    local line_z = create_line_entity(world,"line_z",{0,0+y_add,0},{0,0+y_add,1},0xffff0000,"main_view",parent)
    local cone_z = create_cone_entity(world,{0,0,1,1},{0.06,0.1,0.06},{0.5*math.pi,0,0,0}, {0,0+y_add,1}, "cone_z",parent)
    local center = create_box_entity(world,{1,1,1,1},{0.12,0.12,0.12}, {0,0+y_add,0}, "box_o",parent)
    return {
        eid = parent,
        line_x =line_x,
        cone_x =cone_x,
        line_y =line_y,
        cone_y =cone_y,
        line_z =line_z,
        cone_z =cone_z,
        center =center,
    }
end

return Util