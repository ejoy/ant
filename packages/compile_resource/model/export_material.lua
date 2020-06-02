local fs_local = import_package "ant.utility".fs_local
local stringify = import_package "ant.serialize".stringify
local mc = import_package "ant.math".constant
local util = require "model.util"
local fs = require "filesystem.local"

local image_extension = {
    ["image/jpeg"] = ".jpg",
    ["image/png"] = ".png",
    ["image/bmp"] = ".bmp",
}

local function tov4(v, def)
    if v == nil then
        return def
    end
    if #v == 4 then
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

return function (output, glbdata, exports)
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
    local pbrm_folder = output / "materials"

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
    
    local function to_sampler(sampleidx)
        local gltfsampler = sampleidx and samplers[sampleidx + 1] or default_sampler_flags
    
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
        local imgname = export_image(tex.source)
        local texture_desc = {
            path = "./"..imgname,
            sampler = to_sampler(tex.sampler),
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

    local stages = {
        basecolor = 0,
        metallic_roughness = 1,
        normal = 2,
        occlusion = 3,
        emissive = 4,
    }

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            local filename = fetch_texture_info(tex_desc.index, name, normalmap, colorspace)
            return {
                texture = proxy "resource" ("./../images/" .. filename),
                stage = stages[name]
            }
        end
    end

    local materialfiles = {}
    if materials then
        for matidx, mat in ipairs(materials) do
            local name = mat.name or tostring(matidx)
            local pbr_mr = mat.pbrMetallicRoughness

            local material = {
                fx          = proxy "resource" ("/pkg/ant.resources/materials/fx/pbr_default.fx"),
                state       = "/pkg/ant.resources/materials/states/default.state",
                properties  = {
                    s_basecolor = handle_texture(pbr_mr.baseColorTexture, "basecolor", false, "sRGB"),
                    s_metallic_roughness = handle_texture(pbr_mr.metallicRoughnessTexture, "metallic_roughness", false, "linear"),
                    s_normal = handle_texture(mat.normalTexture, "normal", true, "linear"),
                    s_occlusion = handle_texture(mat.occlusionTexture, "occlusion", false, "linear"),
                    s_emissive = handle_texture(mat.emissiveTexture, "emissive", false, "sRGB"),
    
                    u_basecolor_factor = proxy "vector" (tov4(pbr_mr.baseColorFactor, mc.T_ONE_PT)),
                    u_metallic_roughness_factor = proxy "vector" {
                        0.0, -- keep for occlusion factor
                        pbr_mr.roughnessFactor or 0.0,
                        pbr_mr.metallicFactor or 0.0,
                        pbr_mr.metallicRoughnessTexture and 1.0 or 0.0,
                    },
                    u_emissive_factor = proxy "vector" (tov4(mat.emissiveFactor, mc.T_ZERO)),
                    u_material_texture_flags = proxy "vector" {
                        pbr_mr.baseColorTexture and 1.0 or 0.0,
                        mat.normalTexture and 1.0 or 0.0,
                        mat.emissiveTexture and 1.0 or 0.0,
                        mat.occlusionTexture and 1.0 or 0.0,
                    },
                    u_IBLparam = proxy "vector" {
                        1.0, -- perfilter cubemap mip levels
                        1.0, -- IBL indirect lighting scale
                        0.0, 0.0,
                    },
                    u_alpha_info = proxy "vector" {
                        mat.alphaMode == "OPAQUE" and 0.0 or 1.0, --u_alpha_mask
                        mat.alphaCutoff or 0.0,
                        0.0, 0.0,
                    }
                },
            }

            local function refine_name(name)
                local newname = name:gsub("['\\/:*?\"<>|]", "_")
                return newname
            end
            local filepath = pbrm_folder / refine_name(name) .. ".material"
            fs_local.write_file(filepath, stringify(material, conv))

            materialfiles[matidx] = util.subrespath(output, filepath)
        end
    end

    exports.material = materialfiles
end
