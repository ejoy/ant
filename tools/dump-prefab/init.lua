local serialize = import_package "ant.serialize"
local fs        = require "filesystem"
local math3d    = require "math3d"

local ecs = dofile "/pkg/ant.luaecs/ecs.lua"
local w = ecs.world()

local prefab        = require "prefab"
local mesh          = require "mesh"
local material      = require "material"
local light         = require "light"
local lm_prefilter  = require "lightmap_prefilter"

w:register { name = "id",       type = "lua" }
w:register { name = "parent",   type = "lua" }
w:register { name = "mesh",     type = "lua" }
w:register { name = "material", type = "lua"}
w:register { name = "srt",      type = "lua" }
w:register { name = "sorted",   order = true }
w:register { name = "worldmat", type = "lua" }
w:register { name = "light",    type = "lua"}
w:register { name = "lightmap", type = "lua"}
w:register { name = "lightmapper"}
w:register { name = "lightmap_result", type = "lua"}

local function log(info, ...)
    print(info, ...)
end

local log_detail = log

local respath = fs.path(arg[2])
if not fs.exists(respath) then
    error("invalid respath: " .. respath:string())
end

if respath:equal_extension "glb" then
    --fix vscode debug bug
    respath = fs.path(respath:string() .. "|mesh.prefab")
end

local lfs = require "filesystem.local"
local outputdir = respath:parent_path():localpath() / "output"
if lfs.exists(outputdir) then
    lfs.remove_all(outputdir)
end
lfs.create_directories(outputdir)

w:new{
    lightmapper = true,
    lightmap_result = lm_prefilter.prefilter(respath)
}

local lmr_path = outputdir / "lightmaps"
if not lfs.exists(lmr_path) then
    lfs.create_directories(lmr_path)
end
local lmr_e = w:singleton("lightmapper", "lightmap_result:in")
lm_prefilter.save(lmr_path / "lightmap_result.prefab", {
    policy = {
        "ant.render|lightmap_result",
        "ant.general|name",
    },
    data = {
        lightmap_result = lmr_e.lightmap_result,
        lightmapper = true,
        name = "lightmap_result"
    }
})

prefab.instance(w, respath:string())

for v in w:select "parent:update id:in" do
    v.parent = v.parent.id
end

for v in w:select "mesh:update material:update lightmap:in" do
    v.mesh = mesh.load(tostring(v.mesh))
    v.material = material.load(tostring(v.material), outputdir)
end

for v in w:select "light:update make_shadow?in" do
    v.light = light.load(v.light, v.make_shadow)
    v.light.make_shadow = v.make_shadow
end

local function update_worldmat(v, parent_worldmat)
    if parent_worldmat then
        if v.srt == nil then
            v.worldmat = parent_worldmat
        else
            v.worldmat = math3d.mul(parent_worldmat, v.srt)
        end
    else
        v.worldmat = v.srt
    end
    return v.worldmat or false
end

local cache = {}
for v in w:select "sorted id:in parent?in srt?in worldmat:new" do
    if v.parent == nil then
        cache[v.id] = update_worldmat(v)
    else
        local parent = cache[v.parent]
        if parent ~= nil then
            cache[v.id] = update_worldmat(v, parent)
        else
            v.scene_sorted = false -- yield
        end
    end
end

local function writefile(filename, data)
    do
        local f <close> = io.open(filename:string(), "r")
        if f then
            return
        end
    end
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local function to_srt(wm)
    local s, r, t = math3d.srt(wm)
    return {
        s = math3d.tovalue(s),
        r = math3d.tovalue(r),
        t = math3d.tovalue(t),
    }
end
local output = {}

local num_models = 0
local light_counter = {
    directional = 0,
    point = 0,
    spot = 0,
    area = 0,
}

for v in w:select "worldmat:in mesh:in material:in lightmap:in" do
    local e = to_srt(v.worldmat)
    e.mesh = v.mesh.name
    e.material = v.material.name
    e.lightmap = v.lightmap

    num_models = num_models + 1

    output[#output+1] = e
    writefile(outputdir / v.mesh.name, v.mesh.value)
    writefile(outputdir / v.material.name, v.material.value)

    --log_detail("model:", v.mesh.value.name or "[NO NAME]", "lightmap:", e.lightmap.size, "material:", v.material.name)
end

for v in w:select "worldmat:in light:in" do
    local e = to_srt(v.worldmat)
    e.light = v.light.name
    e.lightdata = v.light.value
    log_detail("light:", e.lightdata.name or "[NO NAME]", "type:", e.lightdata.type)
    local function is_bake_light_type(t)
        return t == "station" or t == "static"
    end
    if is_bake_light_type(e.lightdata.motion_type) then
        light_counter[e.lightdata.type] = light_counter[e.lightdata.type] + 1

        if e.lightdata.type == "directional" then
            output[#output+1] = e
        else
            log("ligt not bake right now:%s", e.lightdata.type)
        end
    end
end

writefile(outputdir / "output.txt", serialize.stringify(output))

log("success output:", outputdir / "output.txt", "num models:", num_models, "num material:", material.count())
log("lights:")
for k, v in pairs(light_counter) do
    log("\t", k, ":", v)
end

