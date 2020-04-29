local fs = require "filesystem.local"
local export_meshbin = require "mesh.export_meshbin"

local fs_local = require "utility.fs_local"

local math3d = require "math3d"

local seri_stringfiy = require "serialize.stringify"
local seri = require "serialize.serialize"
return function(inputfile, meshfolder, glbscene, glbbin, materialfiles, meshconfig)
        fs.create_directories(meshfolder)

        local function get_obj_name(obj, meshidx, def_name)
            if obj.name then
                return obj.name
            end
            return def_name .. meshidx
        end

        local function default_mesh_cfg(mesh_path, layouts)
            return  {
                layouts         = layouts,
                mesh_path       = mesh_path:string(),
                type            = "mesh",
            }
        end
        
        local meshbin_file = meshfolder / inputfile:filename():replace_extension ".meshbin"
        local success, err = export_meshbin(glbscene, glbbin, meshbin_file, meshconfig)

        if not success then
            error(("export to 'meshbin' file failed:\n%s\n%s\n%s"):format(inputfile:string(), meshbin_file:string(), err))
        end

        local meshfile = fs.path(meshbin_file):replace_extension ".mesh"
        fs_local.write_file(meshfile, seri_stringfiy.map(default_mesh_cfg(meshbin_file, meshconfig.layouts)))

        local function get_srt(node)
            if node.matrix then
                local s, r, t = math3d.srt(math3d.matrix(node.matrix))
                return {
                    s = math3d.tovalue(s),
                    r = math3d.tovalue(r),
                    t = math3d.tovalue(t),
                }
            end

            return {
                s = node.scale or {1, 1, 1, 0},
                r = node.rotation or {0, 0, 0, 1},
                t = node.translation or {0, 0, 0, 1}
            }
        end

        local function create_hierarchy_entity(parent, node, uuid)
            local policy = {
                "ant.scene|transform_policy",
                "ant.general|name",
            }
            if parent then
                policy[#policy+1] = "ant.scene|hierarchy_policy"
            end
            return {
                policy = policy,
                data = {
                    transform = {srt=get_srt(node)},
                    parent = parent,
                    name = node.name,
                    scene_entity = true,
                    serialize = uuid,
                }
            }
        end

        local function create_mesh_entity(parent, node, meshname, uuid)
            local policy = {
                "ant.general|name",
                "ant.render|mesh",
                "ant.render|render",
            }

            local data = {
                scene_entity = true,
                can_render = true,
                transform = {srt=get_srt(node)},
                mesh        = meshfile:string() .. ":" .. meshname,
                material    = materialfiles[node.material],
                name = node.name,
                serialize = uuid,
                parent = parent,
            }

            if parent then
                policy[#policy+1] = "ant.scene|hierarchy_policy"
            end

            return {
                policy = policy,
                data = data,
            }
        end

        local scenenodes = glbscene.nodes
        local tree = {}
        local meshes = {}
        local function traverse_scene_tree()
            for _, scene in ipairs(glbscene.scenes) do
                local function build_tree(nodes, parentidx)
                    for _, nodeidx in ipairs(nodes) do
                        tree[nodeidx] = parentidx
                        local node = scenenodes[nodeidx+1]
                        if node.mesh then
                            meshes[node.mesh] = nodeidx
                        end

                        if node.children then
                            build_tree(node.children, nodeidx)
                        end
                    end
                end

                build_tree(scene.nodes, -1)
            end
        end

        traverse_scene_tree()

        local cache = {}

        local function find_hierarchy_chain(nodeidx, chain)
            if cache[nodeidx] then
                return
            end

            chain[#chain+1] = nodeidx
            local parent = tree[nodeidx]
            cache[nodeidx] = {
                uuid = seri.create(),
                parent = parent,
            }
            if parent ~= -1 then
                find_hierarchy_chain(parent, chain)
            end
        end

        for meshidx, mesh in ipairs(glbscene.meshes) do
            local mesh_nodeidx = meshes[meshidx-1]

            local chain = {}
            find_hierarchy_chain(mesh_nodeidx, chain)

            for idx, nodeidx in ipairs(chain) do
                local node = scenenodes[nodeidx+1]
                local c = cache[nodeidx]
                local pc = cache[c.parent]
                local parent_uuid = pc and pc.uuid or nil

                local entity
                local entityname
                if node.mesh then
                    entity = create_mesh_entity(parent_uuid, node, get_obj_name(mesh, meshidx, "mesh"), c.uuid)
                    entityname = get_obj_name(node, idx, "mesh_entity")
                else
                    entity = create_hierarchy_entity(parent_uuid, node, c.uuid)
                    entityname = get_obj_name(node, idx, "hie_entity")
                end

                fs_local.write_file(meshfolder / entityname .. ".txt", seri_stringfiy.map(entity))
            end
        end
end