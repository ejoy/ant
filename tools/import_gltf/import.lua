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
        write_file(texpath, stringify(texture_desc, true, true))
        return texpath:string()
    end

    local function handle_texture(tex_desc, name, normalmap, colorspace)
        if tex_desc then
            tex_desc.path = fetch_texture_info(tex_desc.index, name, normalmap, colorspace)
            tex_desc.index = nil
            return tex_desc
        end
    end

    local pbrm_paths = {}
    for matidx, mat in ipairs(glbscene.materials) do
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
        write_file(filepath, stringify(pbrm, true, true))

        pbrm_paths[#pbrm_paths+1] = filepath
    end
end

local filecvt_util = require "fileconvert.util"
local gltf2ozz = filecvt_util.valid_tool_exe_path "gltf2ozz"

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

    local success, msg = filecvt_util.spawn_process(commands)
    print((success and "success" or "failed"), msg)
end

export_pbrm(pbrm_folder)
export_animation(animation_folder)
export_meshes(mesh_folder)
