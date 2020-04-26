local fs = require "filesystem.local"
local export_meshbin = require "mesh.export_meshbin"

local fs_util = require "utility.fs_util"

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
        fs_util.write_file(meshfile, seri_stringfiy.map(default_mesh_cfg(meshbin_file, meshconfig.layouts)))

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

        local function create_hierarchy_entity(parent, node)
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
                }
            }
        end

        local function create_mesh_entity(parent, node, meshname)
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
                rendermesh = {},
                name = node.name,
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

                build_tree(scene.nodes, 0)
            end
        end

        traverse_scene_tree()

        local cache = {}

        local function find_hierarchy_chain(nodeidx, chain)
            if cache[nodeidx] then
                return
            end

            cache[nodeidx] = seri.create()
            chain[#chain+1] = nodeidx
            local parent = tree[nodeidx]
            if parent ~= 0 then
                find_hierarchy_chain(parent, chain)
            end
        end


        local scenemeshes = glbscene.meshes
        for meshidx, mesh in ipairs(scenemeshes) do
            local nodeidx = meshes[meshidx]

            local chain = {}
            find_hierarchy_chain(nodeidx, chain)

            for i=1, #chain do
                local node = scenenodes[i]
                local parent = chain[i+1] and cache[chain[i+1]] or nil
                local entity
                local entityname
                if node.mesh then
                    entity = create_mesh_entity(parent, node, get_obj_name(mesh, meshidx, "mesh"))
                    entityname = get_obj_name(node, i, "mesh_entity")
                else
                    entity = create_hierarchy_entity(parent, node)
                    entityname = get_obj_name(node, i, "hie_entity")
                end

                fs_util.write_file(meshfolder / entityname .. ".txt", seri_stringfiy.map(entity))
            end
        end
end