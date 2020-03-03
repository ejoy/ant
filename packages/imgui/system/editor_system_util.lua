local Util = {}
local mathpkg   = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local geopkg    = import_package "ant.geometry"
local fs        = require "filesystem"
local assetmgr = import_package "ant.asset".mgr
local camerautil = import_package "ant.render".camera
local RES_IDX = 10080

local function line(start_pos, end_pos, color)  
    local vb, ib = {}, {}       
    local function add_vertex(pos, clr)
        local x,y,z = table.unpack(pos)
        -- log.trace(x,y,z,clr)
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


local function circle(color)
    local vb, ib = {}, {}      
    local radius = 1 
    local function add_vertex(pos, clr)
        local x,y,z = table.unpack(pos)
        -- log.trace(x,y,z,clr)
        table.insert(vb, {x,y,z, clr})          
    end
    local function add_line(p1, p2, color)
        add_vertex(p1, color)
        add_vertex(p2, color)
        -- call 2 times
        table.insert(ib, #ib)
        table.insert(ib, #ib)
    end
    local start_p = {0,radius,0}
    for i = 1,360 do
        local r = i/180*math.pi
        local cos = radius*math.cos(r)
        local sin = radius*math.sin(r)
        local p = {0,cos,sin}
        add_line(start_p, p, color)
        start_p = p
    end
    return vb, ib
end

local function create_ring_entity(world,color,size,rot,name,parent,dir)
    local computil  = import_package "ant.render".components
    color[4] = 0.6
    return world:create_entity {
        policy={
            "ant.render|name",
            "ant.render|mesh",
            "ant.render|render",
            "ant.scene|hierarchy",
            "ant.objcontroller|select",
            "ant.imgui|gizmo_object",
        },
        data = {
            transform = {
                s = size or {1, 1, 1,0},
                r = rot or {0, 0, 0, 0},
                t = pos or {0, 0, 0, 1},
                parent = parent,
            },
            rendermesh = {},
            mesh = {ref_path = fs.path "/pkg/ant.resources/depiction/meshes/ring.mesh"},
            material = computil.assign_material(
                    fs.path "/pkg/ant.resources/depiction/materials/gizmo_front_singlecolor.material",
                    {uniforms = {u_color = {type="v4", name="u_color", value=color}},}),
            --can_cast = true,
            can_render = true,
            name = name,
            can_select = true,
            hierarchy_visible = false,
            gizmo_object = {dir = dir},
            hierarchy = {},
            --serialize = seriazlizeutil.create(),
        },
    }
end



local function create_line_entity(world, name, start_pos,end_pos,color,parent,dir)
    local util  = import_package "ant.render".components
    -- local geopkg = import_package "ant.geometry"
    -- local geolib = geopkg.geometry

    local gridid = world:create_entity {
        policy = {
            "ant.render|name",
            -- "ant.render|mesh",
            "ant.render|render",
            "ant.scene|hierarchy",
            "ant.objcontroller|select",
            "ant.imgui|gizmo_object",
        },
        data = {
            transform = mu.identity_transform(),
            rendermesh = {},
            material = util.assign_material(fs.path "/pkg/ant.resources" /"depiction" / "materials" / "gizmo_line.material"),
            name = name,
            can_render = true,
            can_select = true,
            gizmo_object = {dir = dir},
            hierarchy_visible = true,
            hierarchy = {},
        },
    }
    local grid = world[gridid]
    grid.transform.parent = parent
    local vb, ib = line(start_pos, end_pos, color)
    local gvb = {"fffd"}
    for _, v in ipairs(vb) do
        for _, vv in ipairs(v) do
            table.insert(gvb, vv)
        end
    end

    local num_vertices = #vb
    local num_indices = #ib

    local reskey = fs.path(string.format("//res.mesh/line_%s.mesh",RES_IDX))
    RES_IDX = RES_IDX + 1
    grid.rendermesh.reskey = assetmgr.register_resource(reskey,util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
    return gridid
end

local function create_circle_entity(world, name,color,rot,parent,dir)
    local util  = import_package "ant.render".components

    local gridid = world:create_entity {
        policy = {
            "ant.render|name",
            "ant.render|render",
            -- "ant.render|mesh",
            "ant.scene|hierarchy",
            "ant.objcontroller|select",
            "ant.imgui|gizmo_object",
        },
        data = {
            transform = {
                s = {1, 1, 1,0},
                r = rot or {0, 0, 0, 0},
                t = {0, 0, 0, 1},
                parent = parent,
            },
            rendermesh = {},
            material = util.assign_material(fs.path "/pkg/ant.resources" /"depiction" / "materials" / "gizmo_front_line.material"),
            name = name,
            can_render = true,
            can_select = true,
            gizmo_object = {dir = dir},
            hierarchy_visible = true,
            hierarchy = {},

        }
    }
    local grid = world[gridid]
    grid.transform.parent = parent
    local vb, ib = circle(color)
    local gvb = {"fffd"}
    for _, v in ipairs(vb) do
        for _, vv in ipairs(v) do
            table.insert(gvb, vv)
        end
    end

    local num_vertices = #vb
    local num_indices = #ib

    local reskey = fs.path(string.format("//res.mesh/circle_%s.mesh",RES_IDX))
    RES_IDX = RES_IDX + 1
    grid.rendermesh.reskey = assetmgr.register_resource(reskey,util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
    return gridid
end

local function create_cone_entity(world, color, size,rot,pos, name,parent,dir)
    local computil  = import_package "ant.render".components
    return world:create_entity {
        policy = {
            "ant.render|name",
            "ant.render|render",
            "ant.render|mesh",
            "ant.scene|hierarchy",
            "ant.objcontroller|select",
            "ant.imgui|gizmo_object",
        },
        data = {
            transform = {
                s = size or {1, 1, 1,0},
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
            can_select = true,
            name = name,
            gizmo_object = {dir=dir},
            hierarchy_visible = true,
            hierarchy = {},
        },
    }
end

local function create_box_entity(world, color, size, pos, name,parent,dir)
    local computil  = import_package "ant.render".components
    return world:create_entity {
        policy = {
            "ant.render|name",
            "ant.scene|hierarchy",
            "ant.render|render",
            "ant.render|mesh",
            "ant.objcontroller|select",
            "ant.imgui|gizmo_object",
        },
        data = {
            transform = {
                s = size or {1, 1, 1,0},
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
            name = name,
            can_select = true,
            gizmo_object = {dir=dir},
            hierarchy_visible = true,
            hierarchy = {},
        },

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
    local function create_gizmo_object(name,parent,ignore_scale)
        local trans = mu.srt()
        trans.parent = parent
        local args = {
            policy={
                "ant.render|name",
                "ant.scene|hierarchy",
                "ant.imgui|gizmo_object"
            },
            data={
                transform = trans,
                name = name,
                hierarchy = {},
                -- serialize = seriazlizeutil.create(),
                hierarchy_visible = true,
                gizmo_object = {},
                -- can_select = true,
            },
        }
        if ignore_scale then
            table.insert(args.policy,"ignore_parent_scale")
            args.data.ignore_parent_scale = true
        end
        local eid = world:create_entity(args)
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
        position.line_x = create_line_entity(world,"line_x",{0,0,0},{line_length,0,0},0xff0000ff,parent,"x")
        position.cone_x = create_cone_entity(world,{1,0,0,1},{0.1,0.13,0.1,0},{0,0,-0.5*math.pi,0,0}, {line_length,0,0,1}, "cone_x",parent,"x")
        position.line_y = create_line_entity(world,"line_y",{0,0,0},{0,line_length,0},0xff00ff00,parent,"y")
        position.cone_y = create_cone_entity(world,{0,1,0,1},{0.1,0.13,0.1,0},{0,0,0,0},{0,line_length,0,1}, "cone_y",parent,"y")
        position.line_z = create_line_entity(world,"line_z",{0,0,0},{0,0,line_length},0xffff0000,parent,"z")
        position.cone_z = create_cone_entity(world,{0,0,1,1},{0.1,0.13,0.1,0},{0.5*math.pi,0,0,0}, {0,0,line_length,1}, "cone_z",parent,"z")
        position.center = create_box_entity(world,{1,1,1,1},{0.15,0.15,0.15,0}, {0,0,0,1}, "box_o",parent)
    end

    do
        local line_length = 1.3
        local scale = {}
        result.scale = scale
        scale.line_length = line_length
        local parent = create_gizmo_object("scale",root)
        scale.eid = parent
        scale.line_x = create_line_entity(world,"line_x",{0,0,0},{line_length,0,0},0xff0000ff,parent,"x")
        scale.box_x = create_box_entity(world,{1,0,0,1},{0.15,0.15,0.15,0}, {line_length,0,0,1}, "box_x",parent,"x")
        scale.line_y = create_line_entity(world,"line_y",{0,0,0},{0,line_length,0},0xff00ff00,parent,"y")
        scale.box_y = create_box_entity(world,{0,1,0,1},{0.15,0.15,0.15,0},{0,line_length,0,1}, "box_y",parent,"y")
        scale.line_z = create_line_entity(world,"line_z",{0,0,0},{0,0,line_length},0xffff0000,parent,"z")
        scale.box_z = create_box_entity(world,{0,0,1,1},{0.15,0.15,0.15,0}, {0,0,line_length,1}, "box_z",parent,"z")
        scale.center = create_box_entity(world,{1,1,1,1},{0.18,0.18,0.18,0}, {0,0,0,1}, "box_o",parent)
    end
    do
        local rotation = {}
        result.rotation = rotation
        local parent = create_gizmo_object("rotation",root)
        rotation.eid = parent
        rotation.line_x = create_circle_entity(world,"line_x",0xff0000ff,{0,0,0,0},parent,"x")
        rotation.ring_x = create_ring_entity(world,{1,0,0,1},{1,1,1,0},{0,0,0.5*math.pi,0,0}, "cylinder_x",parent,"x")
        rotation.line_y = create_circle_entity(world,"line_y",0xff00ff00,{0,0,0.5*math.pi,0,0},parent,"y")
        rotation.ring_y = create_ring_entity(world,{0,1,0,1},{1,1,1,0},{0,0,0,0}, "cylinder_y",parent,"y")
        rotation.line_z = create_circle_entity(world,"line_z",0xffff0000,{0,-0.5*math.pi,0,0},parent,"z")
        rotation.ring_z = create_ring_entity(world,{0,0,1,1},{1,1,1,0},{0.5*math.pi,0,0,0}, "cylinder_z",parent,"z")
    end
    return result
end


local function homogeneous_to_world(homogeneous,view_proj)
    local inverse_pv = ms(view_proj,"iP")
    homogeneous[4] = 1
    local h_world_p = ms(inverse_pv,homogeneous,"*T")
    local t = 1/h_world_p[4]
    local world_p = {h_world_p[1]*t,h_world_p[2]*t,h_world_p[3]*t}
    return world_p
end
local function project_screen_onto_plane(screen_pos,plane_point,plane_normal,view_proj)
    screen_pos[3] = 0
    local ray_origin = homogeneous_to_world(screen_pos,view_proj)
    screen_pos[3] = 1.0
    local ray_end = homogeneous_to_world(screen_pos,view_proj)
    local ray_normal = ms( ray_end,ray_origin,"-nT")
    local b = ms(ray_normal,plane_normal,".T")
    local a = ms(plane_normal,plane_point,ray_origin,"-.T")
    local t = a[1]/b[1]
    local rt = {t*ray_normal[1],t*ray_normal[2],t*ray_normal[3]}
    local point = {ray_origin[1]+rt[1],ray_origin[2]+rt[2],ray_origin[3]+rt[3]}
    return point
end

function Util.mouse_project_onto_plane(world,mouse_pos,plane_point,plane_normal)
    local mq = world:singleton_entity "main_queue"
    local viewport = mq.render_target.viewport
    local win_w,win_h = viewport.rect.w,viewport.rect.h
    local screen_pos = {2.0*mouse_pos[1]/win_w-1,1.0-2.0*mouse_pos[2]/win_h}
    local camera = world[mq.camera_eid].camera
    local _, _, view_proj = ms:view_proj(camera, camera.frustum, true)
    local p = project_screen_onto_plane(screen_pos,plane_point,plane_normal,view_proj)
    return p
end

return Util
