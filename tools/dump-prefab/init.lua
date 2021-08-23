local assetmgr = import_package "ant.asset"
local serialize = import_package "ant.serialize"
local math3d = require "math3d"
local ecs = dofile "/pkg/ant.luaecs/ecs.lua"
local w = ecs.world()
local maxid = 0

w:register { name = "id", type = "lua" }
w:register { name = "parent", type = "lua" }
w:register { name = "mesh", type = "lua" }
w:register { name = "srt", type = "lua" }
w:register { name = "sorted", order = true }
w:register { name = "worldmat", type = "lua" }

local create_prefab; do
    local function create_template(_, t)
        local prefab = {}
        for _, v in ipairs(t) do
            local e = {}
            if v.prefab then
                e.prefab = create_prefab(v.prefab)
                if v.args and v.args.root then
                    e.root = v.args.root
                end
            else
                maxid = maxid + 1
                e.id = maxid
                if v.action and v.action.mount then
                    e.parent = v.action.mount
                end
                if v.data.mesh then
                    e.mesh = assetmgr.resource(v.data.mesh)
                end
                if v.data.transform then
                    e.srt = math3d.matrix(v.data.transform)
                end
            end
            prefab[#prefab+1] = e
        end
        return prefab
    end
    local callback = { create_template = create_template }
    function create_prefab(filename)
        return assetmgr.resource(filename, callback)
    end
end

local function instance(prefab, root)
    for _, e in ipairs(prefab) do
        if e.prefab then
            if e.root then
                instance(e.prefab, prefab[e.root])
            else
                instance(e.prefab)
            end
        else
            if e.parent then
                if e.parent == "root" then
                    e.parent = root
                else
                    e.parent = prefab[e.parent]
                end
            end
            e.sorted = true
            w:new(e)
        end
    end
end

instance(create_prefab(arg[2]))

for v in w:select "parent:update id:in" do
    v.parent = v.parent.id
end

for v in w:select "mesh:update" do
    v.mesh = tostring(v.mesh)
end

local function update_worldmat(v, parent_worldmat)
	if parent_worldmat then
		if v.srt == nil then
			v.worldmat = parent_worldmat
		else
			v.worldmat = math3d.mul(parent_worldmat, v.srt)
		end
	else
		if v.srt == nil then
			v.worldmat = nil
		else
			v.worldmat = v.srt
		end
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

local output = {}
for v in w:select "worldmat:in mesh:in" do
    local s, r, t = math3d.srt(v.worldmat)
    output[#output+1] = {
        s = math3d.tovalue(s),
        r = math3d.tovalue(r),
        t = math3d.tovalue(t),
        mesh = v.mesh,
    }
end

print("\n"..serialize.stringify(output))
