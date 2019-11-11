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

local function export_pbrm(pbrm_path)
    fs.create_directories(pbrm_path)

    local function fetch_texture_info(texidx)
        local tex = textures[texidx]

        return {
            sampler = samplers[tex.sampler],
            source = export_image(image_folder, tex.source),
        }
    end

    local function handle_texture(tex_desc)
        if tex_desc then
            tex_desc.texture = fetch_texture_info(tex_desc.index)
            return tex_desc
        end
    end

    local function handle_mr(pbr_mr)
        handle_texture(pbr_mr.baseColorTexture)
        handle_texture(pbr_mr.metallicRoughnessTexture)
        return pbr_mr
    end

    local pbrm_paths = {}

    for matidx, mat in ipairs(glbscene.materials) do
        local name = mat.name or tostring(matidx)
        local pbrm = {
            pbrMetallicRoughness    = handle_mr(mat.pbrMetallicRoughness),
            normalTexture           = handle_texture(mat.normalTexture),
            occlusionTexture        = handle_texture(mat.occlusionTexture),
            emissiveTexture         = handle_texture(mat.emissiveTexture),
            emissiveFactor          = mat.emissiveFactor,
            alphaMode               = mat.alphaMode,
            alphaCutoff             = mat.alphaCutoff,
            doubleSided             = mat.doubleSided,
        }

        local filepath = pbrm_path / name .. ".pbrm"
        write_file(filepath, stringify(pbrm, true, true))

        pbrm_paths[#pbrm_paths+1] = filepath
    end
end

export_pbrm(pbrm_folder)
export_meshes(mesh_folder)
