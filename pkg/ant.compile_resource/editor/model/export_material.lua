local serialize = import_package "ant.serialize"
local fs = require "filesystem.local"
local utility = require "editor.model.utility"
local datalist = require "datalist"
local texture_compile = require "editor.texture.compile"
local parallel_task   = require "editor.parallel_task"

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

local STATE_FILES = {}
local function read_state_file(statefile)
    local s = STATE_FILES[statefile]
    if s == nil then
        local f <close> = fs.open(statefile)
        local c = f:read "a"
        s = datalist.parse(c)
    end

    return s
end

return function (status)
    local output = status.output
    local glbdata = status.glbdata
    local setting = status.setting
    local localpath = status.localpath
    local glbscene, glbbin = glbdata.info, glbdata.bin
    local materials = glbscene.materials
    if not materials then
        return
    end

    local EXPORTED_FILES = {}
    local images = glbscene.images
    local bufferviews = glbscene.bufferViews
    local buffers = glbscene.buffers
    local textures = glbscene.textures
    local samplers = glbscene.samplers
    local function export_image(imgidx)
        local img = images[imgidx+1]
        local ext = image_extension[img.mimeType]
        if ext == nil then
            if img.uri then
                error("not support base64 format")
            end
            error(("not support image type:%d"):format(img.mimeType))
        end

        local name = img.name or tostring(imgidx)
        if fs.path(name):extension():string() ~= ext then
            name = name .. ext
        end

        local function serialize_image_file(imagename)
            local bv = bufferviews[img.bufferView+1]
            local buf = buffers[bv.buffer+1]
            local begidx = (bv.byteOffset or 0)+1
            local endidx = begidx + bv.byteLength
            assert((endidx - 1) <= buf.byteLength)
            local c = glbbin:sub(begidx, endidx)
            utility.save_file(status, imagename, c)
        end

        local outfile = output / "images" / name

        if not EXPORTED_FILES[outfile:string()] then
            serialize_image_file("./images/"..name)
            EXPORTED_FILES[outfile:string()] = true
        end
        return name
    end

    local TextureExtensions <const> = {
        noop       = setting.os == "windows" and "dds" or "ktx",
        direct3d11 = "dds",
        direct3d12 = "dds",
        metal      = "ktx",
        vulkan     = "ktx",
        opengl     = "ktx",
    }
    local TextureSetting <const> = {
        os = setting.os,
        ext = TextureExtensions[setting.renderer],
    }

    local function export_texture(filename, texture_desc)
        if not EXPORTED_FILES[filename] then
            EXPORTED_FILES[filename] = true
            texture_desc = utility.apply_patch(status, filename, texture_desc)

            local function cvt_img_path(path)
                path = path[1]
                if path:sub(1,1) == "/" then
                    return fs.path(path):localpath()
                end
                return fs.absolute((output / filename):parent_path() / (path:match "^%./(.+)$" or path))
            end

            local imgpath = cvt_img_path(texture_desc.path)
            if not fs.exists(imgpath) then
                error(("try to compile texture file:%s, but texture.path:%s is not exist"):format(filename, imgpath:string()))
            end

            parallel_task.add(status.tasks, function ()
                local ok, err = texture_compile(texture_desc, output / filename, TextureSetting, cvt_img_path)
                if not ok then
                    error("compile failed: " .. filename .. "\n" .. err)
                end
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
            path        = serialize.path("./"..imgname),
            sampler     = to_sampler(tex.sampler),
            normalmap   = normalmap,
            colorspace  = colorspace,
            type        = "texture",
        }

        --TODO: check texture if need compress
        local need_compress<const> = true
        add_texture_format(texture_desc, need_compress)

        local texname       = fs.path(imgname):replace_extension("texture"):string()
        export_texture("./images/" .. texname, texture_desc)

        --we need output texture path which is relate to *.material file, so we need ..
        return serialize.path("./../images/" .. texname)
    end

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            local filename = build_texture_file(tex_desc.index, normalmap, colorspace)
            return {
                texture = filename,
                stage = default_pbr_param[name].stage,
            }
        end
    end

    local function get_state(isopaque)
        local name = isopaque and 
            "/pkg/ant.resources/materials/states/default.state" or
            "/pkg/ant.resources/materials/states/translucent.state"
        return read_state_file(localpath(name))
    end


    status.material = {}
    for matidx, mat in ipairs(materials) do
        local name = mat.name or tostring(matidx)
        local pbr_mr = mat.pbrMetallicRoughness

        local isopaque = mat.alphaMode == nil or mat.alphaMode == "OPAQUE"
        local material = {
            fx          = {shader_type = "PBR"},
            state       = get_state(isopaque),
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
                    mat.alphaCutoff or 1.0,
                    1.0, --occlusion strength
                },
            },
        }

        local setting = {}
        if isopaque then
            setting["ALPHAMODE_OPAQUE"] = 1
        else
            setting["MATERIAL_UNLIT"] = 1
        end
        if mat.alphaCutoff then
            setting["ALPHAMODE_MASK"] = 1
        end

        --Blender will always export glb with 'doubleSided' as true
        local function is_Blender_exporter()
            local asset = glbscene.asset
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

        material.fx.setting = setting
        local function refine_name(name)
            local newname = name:gsub("['\\/:*?\"<>|]", "_")
            return newname
        end
        local materialname = refine_name(name)
        local filename = "./materials/" .. materialname .. ".material"
        material = utility.apply_patch(status, filename, material)
        status.material[matidx] = {
            filename = fs.path(filename),
            material = material,
        }
    end
end
