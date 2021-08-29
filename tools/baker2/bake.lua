--local assetmgr = import_package "ant.asset"
local serialize = import_package "ant.serialize"

local bake2 = require "bake2"
local datalist = require "datalist"
local image = require "image"
local math3d = require "math3d"
local fs = require "filesystem"
local lfs = require "filesystem.local"
local bgfx = require "bgfx"

local pkgpath = fs.path(arg[1])
if not fs.exists(pkgpath) then
    error("invalid output pkgpath, need vfs path:".. pkgpath:string())
end

local scenepath = fs.path(arg[2])
if not fs.exists(scenepath) then
    error("invalid output scenepath, need vfs path: ", scenepath:string())
end

local bakescene_path = scenepath / "output"

local scenefile = bakescene_path / "output.txt"
if not fs.exists(scenefile) then
    error(("not found scene output file:%s, it's not a valid bake path"):format(scenefile:string()))
end

local function readfile(filename)
    local f = fs.open(filename, "rb")
    local c = f:read "a"
    f:close()
    return c
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

local b = bake2.create{
    models      = models,
    materials   = materials,
    lights      = lights,
}
local bakeresult = bake2.bake(b)

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

local function save_bake_lm_data(lm, filename)
    local ti = default_tex_info(lm.size, lm.size, "RGBA32F")
    local lmdata = lm.data
    local m = bgfx.memory_buffer(lmdata)
    local c = image.encode_image(ti, m, {type = "dds", format="RGBA8", srgb=false})
    local f = lfs.open(fs.path(filename), "wb")
    f:write(c)
    f:close()
end

local function save_lightmap(e, lme)
    local local_lmpath = lme.lightmap_path:localpath()
    local name = gen_name(lm.bake_id, e.name)
    local filename = lme.lightmap_path / name
    assert(not fs.exists(filename))
    local local_filename = local_lmpath / name
    local ti = default_tex_info(lm.size, lm.size, "RGBA32F")
    local lmdata = lm.data
    local m = bgfx.memory_buffer(lmdata:data(), ti.storageSize, lmdata)
    local c = image.encode_image(ti, m, {type = "dds", format="RGBA8", srgb=false})
    local f = lfs.open(local_filename, "wb")
    f:write(c)
    f:close()

    local tc = texfile_content:format(filename:string())
    local texfile = filename:replace_extension "texture"
    local local_texfile = local_lmpath / texfile:filename():string()
    f = lfs.open(local_texfile, "w")
    f:write(tc)
    f:close()
    
    lme.lightmap_result[lm.bake_id] = {texture_path = texfile:string(),}
end

for idx, lm in ipairs(bakeresult) do
    save_bake_lm_data(lm, "abc" .. idx .. ".dds")
end

bake2.destroy(b)

-- local function create_world()
--     local ecs = import_package "ant.luaecs"
--     local cr = import_package "ant.compile_resource"
--     local world = ecs.new_world {
--         width  = 0,
--         height = 0,
--     }
--     cr.set_identity "windows_direct3d11"
--     assert(loadfile "/pkg/ant.prefab/prefab_system.lua")({world = world})
--     function world:create_entity_template(v)
--         return v
--     end
--     return world
-- end

-- local world = create_world()

-- print "ok"
