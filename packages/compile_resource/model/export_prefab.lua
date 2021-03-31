local math3d = require "math3d"
local utility = require "model.utility"

local invalid_chars<const> = {
    '<', '>', ':', '/', '\\', '|', '?', '*', ' ', '\t', '\r', '%[', '%]', '%(', '%)'
}

local replace_char<const> = '_'

local function fix_invalid_name(name)
    for _, ic in ipairs(invalid_chars) do
        name = name:gsub(ic, replace_char)
    end

    return name
end

local prefab = {}

local function create_entity(t)
    if t.parent then
        t.policy[#t.policy+1] = "ant.scene|hierarchy_policy"
        t.action = {mount = t.parent}
        t.data["scene_entity"] = true
    end
    table.sort(t.policy)
    prefab[#prefab+1] = {
        policy = t.policy,
        data = t.data,
        action = t.action,
    }
    return #prefab
end

local function get_transform(node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        return {
            s = math3d.tovalue(s),
            r = math3d.tovalue(r),
            t = math3d.tovalue(t),
        }
    end

    return {
        s = node.scale,
        r = node.rotation,
        t = node.translation,
    }
end

local STATE_TYPE = {
    visible     = 0x00000001,
    cast_shadow = 0x00000002,
    selectable  = 0x00000004,
}

local DEFAULT_STATE = STATE_TYPE.visible|STATE_TYPE.cast_shadow|STATE_TYPE.selectable

local function create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    for primidx, prim in ipairs(mesh.primitives) do
        local meshname = mesh.name and fix_invalid_name(mesh.name) or ("mesh" .. meshidx)
        local materialfile
        if prim.material then 
            if exports.material and next(exports.material) then
                local mm = exports.material[prim.material+1]
                local mode = prim.mode or 4
                materialfile = assert(mm[mode])
            else
                error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
            end
        else
            materialfile = "/pkg/ant.resources/materials/pbr_default_cw.material"
        end

        local meshfile = exports.mesh[meshidx+1][primidx]
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end

        local data = {
            scene_entity= true,
            transform   = transform,
            mesh        = meshfile,
            material    = materialfile,
            name        = node.name or "",
            state       = DEFAULT_STATE,
        }

        local policy = {
            "ant.general|name",
            "ant.render|render",
        }

        if node.skin then
            local f = exports.skin[node.skin+1]
            if f == nil then
                error(("mesh need skin data, but no skin file output:%d"):format(node.skin))
            end
            if exports.skeleton == nil then
                error("mesh has skin info, but skeleton not export correctly")
            end

            data.skeleton = exports.skeleton

            --skinning
            data.meshskin = f
            policy[#policy+1] = "ant.animation|skinning"

            --animation
            if next(exports.animations) ~= nil then
                local lst = {}
                data.animation = {}
                for name, file in pairs(exports.animations) do
                    local n = fix_invalid_name(name)
                    data.animation[n] = file
                    lst[#lst+1] = n
                end
                table.sort(lst)
                data.animation_birth = lst[1]
                policy[#policy+1] = "ant.animation|animation"
                policy[#policy+1] = "ant.animation|animation_controller.birth"
            end
        end

        create_entity {
            policy = policy,
            data = data,
            parent = parent,
        }
    end
end

local function create_node_entity(gltfscene, nodeidx, parent)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local nname = node.name and fix_invalid_name(node.name) or ("node" .. nodeidx)
    return create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy"
        },
        data = {
            name = node.name or "",
            scene_entity = true,
            transform = transform,
        },
        parent = parent,
    }
end

local function find_mesh_nodes(gltfscene, scenenodes)
    local meshnodes = {}
    for _, nodeidx in ipairs(scenenodes) do
        local node = gltfscene.nodes[nodeidx+1]
        if node.children then
            local c_meshnodes = find_mesh_nodes(gltfscene, node.children)
            for ni, l in pairs(c_meshnodes) do
                l[#l+1] = nodeidx
                assert(meshnodes[ni] == nil)
                meshnodes[ni] = l
            end
        end
        if node.mesh then
            assert(node.children == nil)
            local meshlist = {}
            assert(meshnodes[nodeidx] == nil)
            meshnodes[nodeidx] = meshlist

            meshlist[#meshlist+1] = nodeidx
        end
    end

    return meshnodes
end

local function righthand2lefthand_transform()
    return {
        s = {-1.0, 1.0, 1.0}
    }
end

return function(output, glbdata, exports)
    prefab = {}

    local gltfscene = glbdata.info
    local sceneidx = gltfscene.scene or 0
    local scene = gltfscene.scenes[sceneidx+1]
    local rootid = create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy",
        },
        data = {
            name = scene.name or "Rootscene",
            transform = righthand2lefthand_transform(),
        },
        parent = "root",
    }

    local meshnodes = find_mesh_nodes(gltfscene, scene.nodes)

    local C = {}
    for mesh_nodeidx, meshlist in pairs(meshnodes) do
        local parent = rootid
        for i=#meshlist, 2, -1 do
            local nodeidx = meshlist[i]
            local p = C[nodeidx]
            if p then
                parent = p
            else
                parent = create_node_entity(gltfscene, nodeidx, parent)
                C[nodeidx] = parent
            end
        end

        local nodeidx = meshlist[1]
        assert(C[nodeidx] == nil)
        C[nodeidx] = parent
        assert(nodeidx == mesh_nodeidx)
        create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
    end
    utility.save_txt_file("./mesh.prefab", prefab)
end
