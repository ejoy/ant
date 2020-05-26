local fs_local = import_package "ant.utility".fs_local
local stringify = import_package "ant.serialize".stringify

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

return function (output, glbdata)
    local conv = {}
    local function proxy(name)
        return function (v)
            local o = {v}
            conv[o] = {
                name = name,
                save = function() return v end
            }
            return o
        end
    end

    local glbscene, glbbin = glbdata.info, glbdata.bin

    local image_folder = output / "images"
    local pbrm_folder = output / "pbrm"

    fs.create_directories(pbrm_folder)
    local images = glbscene.images
    local bufferviews = glbscene.bufferViews
    local buffers = glbscene.buffers
    local textures = glbscene.textures
    local samplers = glbscene.samplers
    local materials = glbscene.materials

    local function export_image(imgidx)
        fs.create_directories(image_folder)
        local img = images[imgidx+1]
        local name = img.name or tostring(imgidx)
        local imgname = name .. image_extension[img.mimeType]
        local imgpath = image_folder / imgname
        if not fs.exists(imgpath) then
            local bv = bufferviews[img.bufferView+1]
            local buf = buffers[bv.buffer+1]
            local begidx = (bv.byteOffset or 0)+1
            local endidx = begidx + bv.byteLength
            assert((endidx - 1) <= buf.byteLength)
            local c = glbbin:sub(begidx, endidx)
            fs_local.write_file(imgpath, c)
        end
        return imgname
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
        if not tex.sampler then
            --TODO
            return
        end
        local imgname = export_image(tex.source)
        local sampler = samplers[tex.sampler+1]
        local texture_desc = {
            path = "./"..imgname,
            sampler = to_sampler(sampler),
            normalmap = normalmap,
            colorspace = colorspace,
            type = "texture",
        }

        --TODO: check texture if need compress
        local need_compress<const> = true
        add_texture_format(texture_desc, need_compress)

        local texpath = output / "images" / name .. ".texture"
        fs_local.write_file(texpath, stringify(texture_desc))
        return name .. ".texture"
    end

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            local filename = fetch_texture_info(tex_desc.index, name, normalmap, colorspace)
            if not filename then
                --TODO
                return
            end
            return proxy "resource" ("./../images/" .. filename)
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

            fs_local.write_file(filepath, stringify(pbrm, conv))
    
            materialfiles[matidx] = "./pbrm/" .. refine_name(name) .. ".pbrm"
        end
    end

    return materialfiles
end
