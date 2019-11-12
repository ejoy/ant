package.cpath = "projects/msvc/vs_bin/Debug/?.dll"
package.path = table.concat(
    {
        "engine/?.lua",
        "packages/?.lua",
        "packages/glTF/?.lua",
    }, ";"
)

local function help_info()
    return [[
        At least two argument, one for import file, one for export folder
    ]]
end

if #arg < 3 then
    print(help_info())
    return
end

local fs = require "filesystem.local"

local inputfile, output_folder = fs.path(arg[1]), fs.path(arg[2])

local glbloader = require "glb"
local glbinfo = glbloader.decode(inputfile:string())

local glbbin = glbinfo.bin
local glbscene = glbinfo.info
local bufferviews = glbscene.bufferViews
local buffers = glbscene.buffers
local samplers = glbscene.samplers
local textures = glbscene.textures
local images = glbscene.images

local function export_meshes(meshpath)
    fs.create_directories(meshpath)

    -- for _, scene in ipairs(glbscene.scenes) do
    --     for _, nodeidx  in ipairs(scene.nodes) do
    --         local meshidx = nodeidx.mesh
            
    --     end
    -- end

end

local function write_file(filepath, c)
    local f = fs.open(filepath, "wb")
    f:write(c)
    f:close()
end

local image_extension = {
    ["image/jpeg"] = ".jpg",
    ["image/png"] = ".png",
}

local image_folder = output_folder  / "images"
local pbrm_folder = output_folder   / "pbrm"
local mesh_folder = output_folder   / "meshes"

local function export_image(image_folder, imgidx)
    local img = images[imgidx]
    local name = img.name or tostring(imgidx)
    local imgpath = image_folder / name .. image_extension[img.mimeType]

    if not fs.exists(imgpath) then

        local bv = bufferviews[img.bufferView+1]
        local buf = buffers[bv.buffer+1]

        local begidx = bv.byteOffset+1
        local endidx = begidx + bv.byteLength
        assert(endidx <= buf.byteLength)
        local c = glbbin:sub(begidx, endidx)

        write_file(imgpath, c)
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

local clamp_tags = {
    CLAMP_TO_EDGE   = 33071,
    MIRRORED_REPEAT = 33648,
    REPEAT          = 10497,
}

local default_sampler_flags = {
    magFilter   = filter_tags["LINEAR"],
    minFilter   = filter_tags["LINEAR"],
    wrapS       = clamp_tags["REPEAT"],
    wrapT       = clamp_tags["REPEAT"],
}

local function to_sampler(gltfsampler)
    local minfilter = gltfsampler.minFilter or default_sampler_flags.minFilter
    local maxFilter = gltfsampler.maxFilter or default_sampler_flags.maxFilter

    local MIP_map = {
        NEAREST = "NEAREST",
        LINEAR = "NEAREST",
        NEAREST_MIPMAP_NEAREST = "NEAREST",
        LINEAR_MIPMAP_NEAREST = "NEAREST",
        NEAREST_MIPMAP_LINEAR = "LINEAR",
        LINEAR_MIPMAP_LINEAR = "LINEAR",
    }

    local MAX_MIN_map = {
        NEAREST = "NEAREST",
        LINEAR = "NEAREST",
        NEAREST_MIPMAP_NEAREST = "NEAREST",
        LINEAR_MIPMAP_NEAREST = "NEAREST",
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
        MIP = MIP_map[minfilter],
        MIN = MAX_MIN_map[minfilter],
        MAX = MAX_MIN_map[maxFilter],
        U = UV_map[wrapS],
        V = UV_map[wrapT],
    }
end

local function export_pbrm(pbrm_path)
    fs.create_directories(pbrm_path)

    local function fetch_texture_info(texidx, normalmap, colorspace)
        local tex = textures[texidx]

        local imgpath = export_image(image_folder, tex.source)
        local sampler = samplers[tex.sampler]
        local texture_desc = {
            path = imgpath,
            sampler = to_sampler(sampler),
            normalmap = normalmap,
            colorspace = colorspace,
            type = "texture",
        }

        local texpath = fs.path(imgpath):replace_extension ".texture"
        write_file(texpath, stringify(texture_desc, true, true))
        return texpath
    end

    local function handle_texture(tex_desc)
        if tex_desc then
            tex_desc.texture = fetch_texture_info(tex_desc.index)
            return tex_desc
        end
    end

    local pbrm_paths = {}
    for matidx, mat in ipairs(glbscene.materials) do
        local name = mat.name or tostring(matidx)
        local pbr_mr = mat.pbrMetallicRoughness
        local pbrm = {
            basecolor = {
                texture = handle_texture(pbr_mr.baseColorTexture),
                factor = pbr_mr.baseColorFactor,
            },
            metallic_roughness = {
                texture = handle_texture(pbr_mr.metallicRoughnessTexture),
                factor = {pbr_mr.metallicFactor, pbr_mr.roughnessFactor,},
            },
            normal = {
                texture = handle_texture(mat.normalTexture),
            },
            occlusion = {
                texture = handle_texture(mat.occlusionTexture),
            },
            emissive = {
                texture = handle_texture(mat.emissiveTexture),
                factor  = mat.emissiveFactor,
            },
            alphaMode   = mat.alphaMode,
            alphaCutoff = mat.alphaCutoff,
            doubleSided = mat.doubleSided,
        }

        local filepath = pbrm_path / name .. ".pbrm"
        write_file(filepath, stringify(pbrm, true, true))

        pbrm_paths[#pbrm_paths+1] = filepath
    end
end

export_pbrm(pbrm_folder)
export_meshes(mesh_folder)
