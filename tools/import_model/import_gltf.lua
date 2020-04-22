local fs = require "filesystem.local"
local glbloader = require "glb"

local subprocess = require "utility.sb_util"
local fs_util = require "utility.fs_util"

local math3d = require "math3d"

local seri_stringfiy = require "serialize.stringify"
local seri = require "serialize.serialize"

local export_meshbin = require "mesh.export_meshbin"

return function (inputfile, output_folder, config)
    local glbinfo = glbloader.decode(inputfile:string())

    local glbbin = glbinfo.bin
    local glbscene = glbinfo.info
    local bufferviews = glbscene.bufferViews
    local buffers = glbscene.buffers
    local samplers = glbscene.samplers
    local textures = glbscene.textures
    local images = glbscene.images

    local materialfiles = {}

    local function export_meshes(meshfolder)
        fs.create_directories(meshfolder)

        local function get_obj_name(obj, meshidx, def_name)
            if obj.name then
                return obj.name
            end
            return def_name .. meshidx
        end

        local function default_mesh_cfg(mesh_path)
            return  {
                skinning_type = "cpu",
                mesh_path = mesh_path,
                type = "mesh",
            }
        end
        
        local meshbin_file = fs.path(inputfile):replace_extenstion ".meshbin"
        local success, err = export_meshbin(glbscene, glbbin, meshbin_file, config.mesh)

        if not success then
            error(("export to 'meshbin' file failed:\n%s\n%s\n%s"):format(inputfile:string(), meshbin_file:string(), err))
        end

        local meshfile = fs.path(meshbin_file):replace_extenstion ".mesh"
        fs_util.write_file(meshfile, seri_stringfiy.map(default_mesh_cfg(meshbin_file)))

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

    local image_extension = {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
    }

    local image_folder = output_folder  / "images"
    local pbrm_folder = output_folder   / "pbrm"
    local mesh_folder = output_folder   / "meshes"
    local animation_folder = output_folder / "animation"

    local function export_image(image_folder, imgidx)
        fs.create_directories(image_folder)

        local img = images[imgidx+1]
        local name = img.name or tostring(imgidx)
        local imgpath = image_folder / name .. image_extension[img.mimeType]
    
        if not fs.exists(imgpath) then
    
            local bv = bufferviews[img.bufferView+1]
            local buf = buffers[bv.buffer+1]
    
            local begidx = bv.byteOffset+1
            local endidx = begidx + bv.byteLength
            assert(endidx <= buf.byteLength)
            local c = glbbin:sub(begidx, endidx)
    
            fs_util.write_file(imgpath, c)
        end
        return imgpath
        
    end
    
    local stringify = require "utility.stringify"
    
    local filter_tags = {
        NEAREST = 9728,
        LINEAR = 9729,
        NEAREST_MIPMAP_NEAREST = 9984,
        LINEAR_MIPMAP_NEAREST = 9985,
        NEAREST_MIPMAP_LINEAR = 9986,
        LINEAR_MIPMAP_LINEAR = 9987,
    }
    
    local filter_names = {}
    for k, v in pairs(filter_tags) do
        assert(filter_names[v] == nil, "duplicate value")
        filter_names[v] = k
    end
    
    local address_tags = {
        CLAMP_TO_EDGE   = 33071,
        MIRRORED_REPEAT = 33648,
        REPEAT          = 10497,
    }
    
    local address_names = {}
    for k, v in pairs(address_tags) do
        assert(address_names[v] == nil)
        address_names[v] = k
    end
    
    local default_sampler_flags = {
        maxFilter   = filter_tags["LINEAR"],
        minFilter   = filter_tags["LINEAR"],
        wrapS       = address_tags["REPEAT"],
        wrapT       = address_tags["REPEAT"],
    }
    
    local function to_sampler(gltfsampler)
        local minfilter = gltfsampler.minFilter or default_sampler_flags.minFilter
        local maxFilter = gltfsampler.maxFilter or default_sampler_flags.maxFilter
    
        local MIP_map = {
            NEAREST = "POINT",
            LINEAR = "POINT",
            NEAREST_MIPMAP_NEAREST = "POINT",
            LINEAR_MIPMAP_NEAREST = "POINT",
            NEAREST_MIPMAP_LINEAR = "LINEAR",
            LINEAR_MIPMAP_LINEAR = "LINEAR",
        }
    
        local MAG_MIN_map = {
            NEAREST = "POINT",
            LINEAR = "LINEAR",
            NEAREST_MIPMAP_NEAREST = "POINT",
            LINEAR_MIPMAP_NEAREST = "POINT",
            NEAREST_MIPMAP_LINEAR = "LINEAR",
            LINEAR_MIPMAP_LINEAR = "LINEAR",
        }
    
        local UV_map = {
            CLAMP_TO_EDGE   = "CLAMP",
            MIRRORED_REPEAT = "MIRROR",
            REPEAT          = "WRAP",
        }
    
        local wrapS, wrapT =    
            gltfsampler.wrapS or default_sampler_flags.wrapS,
            gltfsampler.wrapT or default_sampler_flags.wrapT
    
        return {
            MIP = MIP_map[filter_names[minfilter]],
            MIN = MAG_MIN_map[filter_names[minfilter]],
            MAG = MAG_MIN_map[filter_names[maxFilter]],
            U = UV_map[address_names[wrapS]],
            V = UV_map[address_names[wrapT]],
        }
    end
    
    local function export_pbrm(pbrm_path)
        fs.create_directories(pbrm_path)
    
        local function fetch_texture_info(texidx, name, normalmap, colorspace)
            local tex = textures[texidx+1]
    
            local imgpath = export_image(image_folder, tex.source)
            local sampler = samplers[tex.sampler+1]
            local texture_desc = {
                path = imgpath:string(),
                sampler = to_sampler(sampler),
                normalmap = normalmap,
                colorspace = colorspace,
                type = "texture",
            }
    
            local texpath = imgpath:parent_path() / name .. ".texture"
            fs_util.write_file(texpath, stringify(texture_desc, true, true))
            return texpath:string()
        end
    
        local function handle_texture(tex_desc, name, normalmap, colorspace)
            if tex_desc then
                tex_desc.path = fetch_texture_info(tex_desc.index, name, normalmap, colorspace)
                tex_desc.index = nil
                return tex_desc
            end
        end

        local materials = glbscene.materials
        if materials then
            for matidx, mat in ipairs(materials) do
                local name = mat.name or tostring(matidx)
                local pbr_mr = mat.pbrMetallicRoughness
                local pbrm = {
                    basecolor = {
                        texture = handle_texture(pbr_mr.baseColorTexture, "basecolor", false, "sRGB"),
                        factor = pbr_mr.baseColorFactor,
                    },
                    metallic_roughness = {
                        texture = handle_texture(pbr_mr.metallicRoughnessTexture, "metallic_roughness", false, "linear"),
                        roughness_factor = pbr_mr.roughnessFactor,
                        metallic_factor = pbr_mr.metallicFactor
                    },
                    normal = {
                        texture = handle_texture(mat.normalTexture, "normal", true, "linear"),
                    },
                    occlusion = {
                        texture = handle_texture(mat.occlusionTexture, "occlusion", false, "linear"),
                    },
                    emissive = {
                        texture = handle_texture(mat.emissiveTexture, "emissive", false, "sRGB"),
                        factor  = mat.emissiveFactor,
                    },
                    alphaMode   = mat.alphaMode,
                    alphaCutoff = mat.alphaCutoff,
                    doubleSided = mat.doubleSided,
                }
        
                local function refine_name(name)
                    local newname = name:gsub("['\\/:*?\"<>|]", "_")
                    return newname
                end
                local filepath = pbrm_path / refine_name(name) .. ".pbrm"
                fs_util.write_file(filepath, stringify(pbrm, true, true))
        
                materialfiles[#materialfiles+1] = filepath
            end
        end
    end
    
    local gltf2ozz = fs_util.valid_tool_exe_path "gltf2ozz"
    
    local function export_animation(animation_folder)
        fs.create_directories(animation_folder)
        local commands = {
            gltf2ozz:string(),
            "--file=" .. (fs.current_path() / inputfile):string(),
            stdout = true,
            stderr = true,
            hideWindow = true,
            cwd = animation_folder:string(),
        }
    
        local success, msg = subprocess.spawn_process(commands)
        print((success and "success" or "failed"), msg)
    end
    
    export_pbrm(pbrm_folder)
    export_animation(animation_folder)
    export_meshes(mesh_folder)
end

