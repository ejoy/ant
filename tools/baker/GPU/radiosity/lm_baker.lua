local ecs = ...
local world = ecs.world
local w = world.w

local serialize = import_package "ant.serialize"
local fs = require "filesystem"
local lfs = require "filesystem.local"
local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local lm_baker = ecs.system "lightmap_baker_system"

local scenepath<const>			= fs.path "/pkg/ant.tool.baker/GPU/radiosity/assets/scene"
local sceneprefab<const>		= scenepath / "scene.prefab"

function lm_baker:init_world()
	local p = ecs.create_instance(sceneprefab:string())

	for e in w:select "lightmapper lightmap_path:out" do
		e.lightmap_path = scenepath / "lightmaps"
		assert(fs.exists(scenepath))
		local local_lmpath = scenepath:localpath() / "lightmaps"
		lfs.create_directories(local_lmpath)
	end

	local mq = w:singleton("main_queue", "camera_ref:in")
    local eyepos = math3d.vector(0, 10, -10)
    local camera_ref = mq.camera_ref
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)

	world:pub{"bake"}	--bake all scene
end

local bake_finish_mb = world:sub{"bake_finish"}

local function writeFile(path, data)
    local f = lfs.open(path:localpath(), "w")
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
			local sceneprefab_baked = scenepath / "scene_baked.prefab"
			save_txt_file(sceneprefab_baked, bake_scened)
		end
	end
end