local lfs = require "bee.filesystem"
local utility = require "model.utility"
local texture_compile = require "texture.compile"
local parallel_task = require "parallel_task"

local setting = import_package "ant.settings"
local INV_Z<const> = setting:get "graphic/inv_z"

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

local default_pbr_param = {
    basecolor = {
        texture = "/pkg/ant.resources/textures/pbr/default/basecolor.texture",
        factor = {1, 1, 1, 1},
        stage = 0,
        precision = "lowp"
    },
    metallic_roughness = {
        texture = "/pkg/ant.resources/textures/pbr/default/metallic_roughness.texture",
        factor = {1, 0, 0, 0},
        stage = 1,
    },
    normal = {
        texture = "/pkg/ant.resources/textures/pbr/default/normal.texture",
        stage = 2,
    },
    emissive = {
        texture = "/pkg/ant.resources/textures/pbr/default/emissive.texture",
        factor = {0, 0, 0, 0},
        stage = 3,
    },
    occlusion = {
        texture = "/pkg/ant.resources/textures/pbr/default/occlusion.texture",
        stage = 4,
    }
}

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

local ALPHA_MODE_STATES<const> = {
    OPAQUE  = {
        ALPHA_REF = 0,
        CULL = "CCW",
        DEPTH_TEST = INV_Z and "GREATER" or "LESS",
        MSAA = true,
        WRITE_MASK = "RGBAZ",
    },
    MASK    = {
        ALPHA_REF = 0,
        CULL = "CCW",
        DEPTH_TEST = "ALWAYS",
        MSAA = true,
        BLEND = "ALPHA",
        WRITE_MASK = "RGBA",
    },
    BLEND   = {
        ALPHA_REF = 0,
        CULL = "CCW",
        MSAA = true,
        DEPTH_TEST = INV_Z and "GREATER" or "LESS",
        WRITE_MASK = "RGBA",
        BLEND = "ALPHA",
    }
}

local function copy_state(s)
    local t = {}
    for k, v in pairs(s) do
        t[k] = v
    end
    return t
end

local function get_state(alphamode)
    alphamode = alphamode or "OPAQUE"
    return copy_state(ALPHA_MODE_STATES[alphamode] or error(("Invalid alphamode: %s"):format(alphamode)))
end

local function refine_name(name)
    local newname = name:gsub("['\\/:*?\"<>|#%s]", "_")
    return newname
end

return function (status)
    local output = status.output
    local setting = status.setting
    local gltfscene = status.gltfscene
    local materials = gltfscene.materials
    if not materials then
        return
    end

    local EXPORTED_FILES = {}
    local images = gltfscene.images
    local bufferviews = gltfscene.bufferViews
    local buffers = gltfscene.buffers
    local textures = gltfscene.textures
    local samplers = gltfscene.samplers
    local function export_image(imgidx)
        local img = images[imgidx+1]
        local name = img.name or tostring(imgidx)
        if img.mimeTyp then
            local ext = image_extension[img.mimeType]
            if ext == nil then
                error(("not support image type:%d"):format(img.mimeType))
            end
            if lfs.path(name):extension() ~= ext then
                name = name .. ext
            end
        end

        local function serialize_image_file(imagename)
            if img.uri then
                local c = status.gltf_fetch(img.uri)
                utility.save_file(status, imagename, c)
                return
            end
            local bv = bufferviews[img.bufferView+1]
            local buf = buffers[bv.buffer+1]
            local begidx = (bv.byteOffset or 0)+1
            local endidx = begidx + bv.byteLength
            assert((endidx - 1) <= buf.byteLength)
            local c = buf.bin:sub(begidx, endidx)
            utility.save_file(status, imagename, c)
        end

        local outfile = output / "images" / name

        if not EXPORTED_FILES[outfile:string()] then
            serialize_image_file("images/"..name)
            EXPORTED_FILES[outfile:string()] = true
        end
        return name
    end

    local function export_texture(filename, texture_desc)
        if not EXPORTED_FILES[filename] then
            EXPORTED_FILES[filename] = true
            utility.apply_patch(status, filename, texture_desc, function (name, desc)
                local function cvt_img_path(path)
                    if path:sub(1,1) == "/" then
                        return lfs.path(setting.vfs.realpath(path))
                    end
                    return lfs.absolute((output / filename):parent_path() / (path:match "^%./(.+)$" or path))
                end
                local imgpath = cvt_img_path(desc.path)
                if not lfs.exists(imgpath) then
                    error(("try to compile texture file:%s, but texture.path:%s is not exist"):format(name, imgpath:string()))
                end
                desc.path = imgpath
                parallel_task.add(status.tasks, function ()
                    local ok, err = texture_compile(desc, output / name, setting, status.depfiles)
                    if not ok then
                        error("compile failed: " .. name .. "\n" .. err)
                    end
                end)
            end)

        else
            print("'texture' file already compiled: ", filename)
        end
    end

    local function to_sampler(sampleidx)
        local gltfsampler = sampleidx and samplers[sampleidx + 1] or default_sampler_flags
    
        local minfilter = gltfsampler.minFilter or default_sampler_flags.minFilter
        local maxFilter = gltfsampler.maxFilter or default_sampler_flags.maxFilter
        
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
                    android = "ASTC6x6",
                    ios = "ASTC6x6",
                    windows = texture_desc.normalmap and "BC5" or "BC3",
                }
        else
            texture_desc.format = "RGBA8"
        end
    end

    local function build_texture_file(texidx, normalmap, colorspace)
        local tex = textures[texidx+1]
        local imgname = export_image(tex.source)
        local texture_desc = {
            path        = imgname,
            sampler     = to_sampler(tex.sampler),
            normalmap   = normalmap,
            colorspace  = colorspace,
            type        = "texture",
            mipmap      = true,
        }

        --TODO: check texture if need compress
        local need_compress<const> = true
        add_texture_format(texture_desc, need_compress)

        local texname       = lfs.path(imgname):replace_extension("texture"):string()
        export_texture("images/" .. texname, texture_desc)

        --we need output texture path which is relate to *.material file, so we need ..
        return "../images/" .. texname
    end

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            local filename = build_texture_file(tex_desc.index, normalmap, colorspace)
            return {
                texture = filename,
                stage = default_pbr_param[name].stage,
                sampler = default_pbr_param[name].sampler,
                precision = default_pbr_param[name].precision,
            }
        end
    end

    status.material = {}
    for matidx, mat in ipairs(materials) do
        local name = mat.name or tostring(matidx)
        local pbr_mr = mat.pbrMetallicRoughness
        local alphamode = mat.alphaMode or "OPAQUE"

        local alpha_cutoff = mat.alphaCutoff or 1.0
        local material = {
            fx          = {shader_type = "PBR"},
            state       = get_state(alphamode),
            properties  = {
                s_basecolor          = handle_texture(pbr_mr.baseColorTexture, "basecolor", false, "sRGB"),
                s_metallic_roughness = handle_texture(pbr_mr.metallicRoughnessTexture, "metallic_roughness", false, "linear"),
                s_normal             = handle_texture(mat.normalTexture, "normal", true, "linear"),
                s_emissive           = handle_texture(mat.emissiveTexture, "emissive", false, "sRGB"),
                s_occlusion          = handle_texture(mat.occlusionTexture, "occlusion", false, "linear"),
                u_basecolor_factor   = tov4(pbr_mr.baseColorFactor, default_pbr_param.basecolor.factor),
                u_emissive_factor    = tov4(mat.emissiveFactor, default_pbr_param.emissive.factor),
                u_pbr_factor         = {
                    pbr_mr.metallicFactor or 1.0,
                    pbr_mr.roughnessFactor or 1.0,
                    alpha_cutoff,
                    1.0, --occlusion strength
                },
            },
        }

        local macros = {}
        local setting = {}
        local switch = "off"
        if alphamode == "OPAQUE" then
            macros[#macros+1] = "ALPHAMODE_OPAQUE=1"
            switch = "on"
        elseif alphamode == "MASK" then
            macros[#macros+1] = "ALPHAMODE_MASK=" .. alpha_cutoff
        end

        setting.lighting        = switch
        setting.cast_shadow     = switch
        setting.receive_shadow  = switch

        --Blender will always export glb with 'doubleSided' as true
        local function is_Blender_exporter()
            local asset = gltfscene.asset
            if asset then
                local g = asset.generator
                if g then
                    return g:match 'Khronos glTF Blender I/O'
                end
            end
        end
        if mat.doubleSided and (not is_Blender_exporter()) then
            --default is CCW
            material.state.CULL = "NONE"
        end

        material.fx.macros = macros
        material.fx.setting = setting
        status.material[matidx] = {
            filename = ("materials/%s.material"):format(refine_name(name)),
            content = material,
        }
    end
end
