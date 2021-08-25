local serialize = import_package "ant.serialize"
local fs = require "filesystem"
local math3d = require "math3d"
local ecs = dofile "/pkg/ant.luaecs/ecs.lua"
local w = ecs.world()
local prefab = require "prefab"
local mesh = require "mesh"
local light = require "light"

w:register { name = "id", type = "lua" }
w:register { name = "parent", type = "lua" }
w:register { name = "mesh", type = "lua" }
w:register { name = "srt", type = "lua" }
w:register { name = "sorted", order = true }
w:register { name = "worldmat", type = "lua" }
w:register { name = "light", type = "lua"}

local respath = fs.path(arg[2])
if not fs.exists(respath) then
    error("invalid respath: " .. respath:string())
end

if respath:equal_extension "glb" then
    --fix vscode debug bug
    respath = fs.path(respath:string() .. "|mesh.prefab")
end

prefab.instance(w, respath:string())

for v in w:select "parent:update id:in" do
    v.parent = v.parent.id
end

for v in w:select "mesh:update" do
    v.mesh = mesh.load(tostring(v.mesh))
end

for v in w:select "light:update" do
    v.light = light.load(v.light)
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

local lfs = require "filesystem.local"
local function get_output_dir()
    if arg[3] then
        local outpkgdir = fs.path(arg[3])
        assert(fs.exists(outpkgdir), "vfs pkg path must valid")
        return outpkgdir:localpath() / "output"
    end

    return lfs.absolute(lfs.path(arg[0])):remove_filename() / "output"
end
local outputdir = get_output_dir()
if lfs.exists(outputdir) then
    lfs.remove_all(outputdir)
end
lfs.create_directories(outputdir)

local function to_srt(wm)
    local s, r, t = math3d.srt(wm)
    return {
        s = math3d.tovalue(s),
        r = math3d.tovalue(r),
        t = math3d.tovalue(t),
    }
end
local output = {}
for v in w:select "worldmat:in mesh:in" do
    local e = to_srt(v.worldmat)
    e.mesh = v.mesh.name
    output[#output+1] = e
    writefile(outputdir / v.mesh.name, v.mesh.value)
end

for v in w:select "worldmat:in light:in" do
    local e = to_srt(v.worldmat)
    e.light = v.light.name
    for k, vv in pairs(v.light.value) do
        e[k] = vv
    end
    output[#output+1] = e
end

writefile(outputdir / "output.txt", serialize.stringify(output))
