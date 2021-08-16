local ecs = ...
local world = ecs.world
local w = world.w

local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"

local lm_baker = ecs.system "lightmap_baker_system"

local sceneprefab<const> = "/pkg/ant.tool.lightmap_baker/assets/scene/scene.prefab"
local sceneprefab_baked<const> = "/pkg/ant.tool.lightmap_baker/assets/scene/scene_baked.prefab"

function lm_baker:init_world()
	local p = world:instance(sceneprefab)

	for e in w:select "lightmapper lightmap_path:out" do
		e.lightmap_path = lfs.path(sceneprefab):parent_path() / "lightmap"
	end
	world:pub{"bake"}	--bake all scene
end

local bake_finish_mb = world:sub{"bake_finish"}

local function writeFile(path, data)
    lfs.create_directories(path:parent_path())
    local f = assert(lfs.open(path, "wb"))
    f:write(data)
    f:close()
end

local function save_txt_file(path, data)
    writeFile(path, serialize.stringify(data))
end

function lm_baker:data_changed()
	for _ in bake_finish_mb:each() do
		for e in w:select "lightmapper lightmap_result:in" do
			local bake_scened = {
				{prefab = sceneprefab,},
				e,
			}
			save_txt_file(sceneprefab_baked, bake_scened)
		end
	end
end