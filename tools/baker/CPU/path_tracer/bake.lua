--local assetmgr = import_package "ant.asset"
local serialize = import_package "ant.serialize"

local bake      = require "bake"
local crypt     = require "crypt"
local datalist  = require "datalist"
local image     = require "image"
local math3d    = require "math3d"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local bgfx      = require "bgfx"

local lightmapid= require "lightmap_id"

local sceneprefab_file = fs.path(arg[2])
if not fs.exists(sceneprefab_file) then
    error("scene prefab file not exist:".. sceneprefab_file:string())
end

local scenepath = sceneprefab_file:parent_path()
if not fs.exists(scenepath) then
    error("invalid output scenepath, need vfs path: ", scenepath:string())
end

local bakescene_path = scenepath / "output"
if not fs.exists(bakescene_path) then
    lfs.create_directories(scenepath:localpath() / "output")
end

local scenefile = bakescene_path / "output.txt"
if not fs.exists(scenefile) then
    error(("not found scene output file:%s, it's not a valid bake path"):format(scenefile:string()))
end

local lightmap_path = bakescene_path / "lightmaps"
if not fs.exists(lightmap_path) then
    lfs.create_directories(bakescene_path:localpath() / "lightmaps")
end

local lmr_e, lm_cache = lightmapid.build(scenepath, lightmap_path)

local function readfile(filename)
    local f<close> = fs.open(filename, "rb")
    return f:read "a"
end

local function writefile(filename, c, mode)
    mode = mode or "w"
    local f<close> = lfs.open(filename, mode)
    f:write(c)
end

local scene = datalist.parse(readfile(scenefile))
local filecache = {}
local function read_ref_content(filename)
    local m = filecache[filename]
    if m == nil then
        m = serialize.unpack(readfile(filename))
        filecache[filename] = m
    end
    return m
end

local models = {}
local lights = {}
local materials = {}

local function create_buffer(memory, desc)
    if desc then
        return {
            data    = assert(memory[desc.memory]),
            offset  = desc.offset,
            stride  = desc.stride,
            type    = desc.type,
        }
    end
end

local materialcache = {}

for _, e in ipairs(scene) do
    if e.mesh then
        local material = assert(e.material)
        local meshdata = read_ref_content(bakescene_path / e.mesh)

        local function add_material(materialfile)
            local c = materialcache[materialfile]
            if c == nil then
                materials[#materials+1] = read_ref_content(materialfile)
                c = #materials
                materialcache[materialfile] = c
            end

            return c
        end
        
        local vb = meshdata.vb
        local memory = meshdata.memory
        local wm = math3d.matrix(e)

        local function elem_count(b)
            local m = memory[b.memory]
            return #m // b.stride
        end
        models[#models+1] = {
            worldmat    = math3d.tovalue(wm),
            normalmat   = math3d.tovalue(math3d.transpose(math3d.inverse(wm))),
            positions   = create_buffer(memory, vb.pos),
            normals     = create_buffer(memory, vb.normal),
            tangents    = create_buffer(memory, vb.tangent),
            bitangents  = create_buffer(memory, vb.bitangent),
            texcoords0  = create_buffer(memory, vb.uv0),
            texcoords1  = create_buffer(memory, vb.uv1),
            indices     = create_buffer(memory, meshdata.ib),
            vertexCount = elem_count(vb.pos),
            indexCount  = elem_count(meshdata.ib),
            lightmap    = {
                size = e.lightmap.size,
                id = crypt.uuid(),
            },
            materialidx = add_material(bakescene_path / material),
        }
    elseif e.light then
        local ld = e.lightdata
        lights[#lights+1] = {
            dir = math3d.tovalue(math3d.inverse(math3d.transform(math3d.quaternion(e.r), math3d.vector(0.0, 0.0, 1.0), 0))),
            pos = e.t,
            color = ld.color,
            size = ld.size or 0.3,
            type = ld.type,
            intensity = ld.intensity,
        }
    end
end

local texfile_content<const> = [[
normalmap: false
path: %s
sRGB: true
compress:
    android: ASTC6x6
    ios: ASTC6x6
    windows: BC3
sampler:
    MAG: LINEAR
    MIN: LINEAR
    U: CLAMP
    V: CLAMP
]]

local function default_tex_info(w, h, fmt)
    local bits = image.get_bits_pre_pixel(fmt)
    local s = (bits//8) * w * h
    return {
        width=w, height=h, format=fmt,
        numLayers=1, numMips=1, storageSize=s,
        bitsPerPixel=bits,
        depth=1, cubeMap=false,
    }
end

local function save_lightmap(id, lm, lmr)
    local name = id .. ".dds"
    local filename = lightmap_path / name

    local local_lmpath = lightmap_path:localpath()
    local local_filename = local_lmpath / name
    local ti = default_tex_info(lm.size, lm.size, "RGBA32F")
    local m = bgfx.memory_buffer(lmr.data)
    local c = image.encode_image(ti, m, {type = "dds", format="RGBA32", srgb=false})
    writefile(local_filename, c, "wb")

    local tc = texfile_content:format(filename:string())
    local texfile = filename:replace_extension "texture"
    local local_texfile = local_lmpath / texfile:filename():string()
    writefile(local_texfile, tc, "w")
    return texfile
end

local function save_bake_result(br)
    for idx, r in ipairs(br) do
        local m = models[idx]
        local id = m.lightmap.id
        lm_cache[id].texture_path = save_lightmap(id, m.lightmap, r):string()
    end

    writefile(lightmap_path:localpath() / "lightmap_result.prefab", serialize.stringify({lmr_e}), "w")

    local function check_add_lightmap_result()
        local s = datalist.parse(readfile(sceneprefab_file))
        for _, p in ipairs(s) do
            if p.prefab and p.prefab:match "lightmap_result.prefab" then
                return
            end
        end

        s[#s+1] = {
            action = {
                lightmap_result = {},
            },
            prefab = "./output/lightmaps/lightmap_result.prefab"
        }

        writefile(sceneprefab_file:localpath(), serialize.stringify(s), "w")
    end

    check_add_lightmap_result()
end

local b = bake.create{
    models      = models,
    materials   = materials,
    lights      = lights,
}
save_bake_result(bake.bake(b))
bake.destroy(b)
