local ecs = ...
local world = ecs.world
local w = world.w

local serialize = import_package "ant.serialize"
local fs = require "filesystem"
local lfs = require "filesystem.local"

local lm_baker = ecs.system "lightmap_baker_system"

local scenepath<const>			= fs.path "/pkg/ant.tool.lightmap_baker/assets/scene":localpath()
local sceneprefab<const>		= scenepath / "scene.prefab"
local sceneprefab_baked<const>	= scenepath / "scene_baked.prefab"

function lm_baker:init_world()
	local p = world:instance(sceneprefab:string())

	for e in w:select "lightmapper lightmap_path:out" do
		e.lightmap_path = scenepath / "lightmaps"
		lfs.create_directories(e.lightmap_path)
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

local lightmapper_entity = {
	policy = {
		"ant.render|lightmap_result",
		"ant.general|name",
	},
	data = {
		name = "lightmap_result",
		lightmapper = true,
	},
}

function lm_baker:data_changed()
	for _ in bake_finish_mb:each() do
		for e in w:select "lightmapper lightmap_result:in" do
			lightmapper_entity.data.lightmap_result = e.lightmap_result
			local bake_scened = {
				{prefab = sceneprefab:string(),},
				lightmapper_entity,
			}
			save_txt_file(sceneprefab_baked, bake_scened)
		end
	end
end