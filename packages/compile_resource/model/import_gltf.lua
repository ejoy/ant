local export_prefab = require "model.export_prefab"

local glbpkg    = import_package "ant.glTF"
local glbloader = glbpkg.glb

local utilitypkg= import_package "ant.utility"
local subprocess= utilitypkg.subprocess
local fs_local  = utilitypkg.fs_local

local seri_util = require "model.seri_util"

local seripkg = import_package "ant.serialize"
local seri_stringify = seripkg.stringify

local fs = require "filesystem.local"

local image_extension = {
    ["image/jpeg"] = ".jpg",
    ["image/png"] = ".png",
    ["image/bmp"] = ".bmp",
}

local function tov4(v)
    if v == nil or #v == 4 then
        return v
    end
    
    if #v < 4 then
        local vv = {0, 0, 0, 0}
        for i=1, #v do
            vv[i] = v[i]
        end
        return vv
    end
    return {v[1], v[2], v[3], v[4]}
end

local function export_pbrm(arguments, glbdata)
    local glbscene, glbbin = glbdata.info, glbdata.bin

    local image_folder = arguments.outfolder / "images"
    local pbrm_folder = arguments.outfolder / "pbrm"

    fs.create_directories(pbrm_folder)
    local images = glbscene.images
    local bufferviews = glbscene.bufferViews
    local buffers = glbscene.buffers
    local textures = glbscene.textures
    local samplers = glbscene.samplers
    local materials = glbscene.materials

    local function export_image(image_folder, imgidx)
        fs.create_directories(image_folder)

        local img = images[imgidx+1]
        local name = img.name or tostring(imgidx)
        local imgpath = image_folder / name .. image_extension[img.mimeType]
    
        if not fs.exists(imgpath) then
    
            local bv = bufferviews[img.bufferView+1]
            local buf = buffers[bv.buffer+1]
    
            local begidx = (bv.byteOffset or 0)+1
            local endidx = begidx + bv.byteLength
            assert(endidx <= buf.byteLength)
            local c = glbbin:sub(begidx, endidx)
    
            fs_local.write_file(imgpath, c)
        end
        return imgpath
        
    end

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

    local function add_texture_format(texture_desc, need_compress)
        if need_compress then
            texture_desc.compress = {
                    android = "ASTC4x4",
                    ios = "ASTC4x4",
                    windows = "BC3",
                }
        else
            texture_desc.format = "RGBA8"
        end
    end

    local function fetch_texture_info(texidx, name, normalmap, colorspace)
        local tex = textures[texidx+1]

        local imgpath = export_image(image_folder, tex.source)
        local sampler = samplers[tex.sampler+1]
        local texture_desc = {
            texture = arguments:localpath2subrespath(imgpath):string(),
            sampler = to_sampler(sampler),
            normalmap = normalmap,
            colorspace = colorspace,
            type = "texture",
        }

        --TODO: check texture if need compress
        local need_compress<const> = true
        add_texture_format(texture_desc, need_compress)

        local texpath = imgpath:parent_path() / name .. ".texture"
        fs_local.write_file(texpath, seri_stringify(texture_desc))
        return texpath:string()
    end

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            return arguments:localpath2subrespath(fs.path(fetch_texture_info(tex_desc.index, name, normalmap, colorspace))):string()
        end
    end

    local materialfiles = {}
    if materials then
        for matidx, mat in ipairs(materials) do
            local name = mat.name or tostring(matidx)
            local pbr_mr = mat.pbrMetallicRoughness
            local pbrm = {
                basecolor = {
                    texture = handle_texture(pbr_mr.baseColorTexture, "basecolor", false, "sRGB"),
                    factor = tov4(pbr_mr.baseColorFactor),
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
                    factor  = tov4(mat.emissiveFactor),
                },
                alphaMode   = mat.alphaMode,
                alphaCutoff = mat.alphaCutoff,
                doubleSided = mat.doubleSided,
            }
    
            local function refine_name(name)
                local newname = name:gsub("['\\/:*?\"<>|]", "_")
                return newname
            end
            local filepath = pbrm_folder / refine_name(name) .. ".pbrm"

            fs_local.write_file(filepath, seri_util.seri_pbrm(pbrm))
    
            materialfiles[matidx] = arguments:localpath2subrespath(filepath)
        end
    end

    return materialfiles
end

local function export_animation(arguments)
    local animation_folder = arguments.outfolder / "animation"
    fs.create_directories(animation_folder)
    local gltf2ozz = fs_local.valid_tool_exe_path "gltf2ozz"
    local commands = {
        gltf2ozz:string(),
        "--file=" .. (fs.current_path() / arguments.input):string(),
        stdout = true,
        stderr = true,
        hideWindow = true,
        cwd = animation_folder:string(),
    }

    local success, msg = subprocess.spawn_process(commands)
    print((success and "success" or "failed"), msg)
end

return function (arguments)
    local glbdata = glbloader.decode(arguments.input:string())
    local materialfiles = export_pbrm(arguments, glbdata)
    export_animation(arguments)
    export_prefab(arguments, materialfiles, glbdata, {})
end

