local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	= require "math3d"
local start_frame_sys = ecs.system "start_frame_system"

local function stat_material_info()
	local materials = {}
	local instances = {}
	for e in w:select "material:in render_object:in filter_material:in" do
		local function mark(mi, matpath)
			if instances[mi] == nil then
				instances[mi] = true
				local mobj = mi:get_material()
				if nil == materials[mobj] then
					materials[mobj] = matpath
				end
			end
		end

		mark(e.render_object.material, e.material)
		for _, m in pairs(e.filter_material) do
			mark(m.material, e.material)
		end
	end

	local material_attribs = {}
	local material_paths = {}
	for mobj, mpath in pairs(materials) do
		local attribs = mobj:attribs()
		table.move(attribs, 1, #attribs, #material_attribs+1, material_attribs)
		material_paths[#material_paths+1] = mpath
	end

	local instance_attribs = {}
	local numinstance = 0
	for mi in pairs(instances) do
		local attribs = mi:attribs()
		table.move(attribs, 1, #attribs, #instance_attribs+1, instance_attribs)
		numinstance = numinstance + 1
	end

	print("Material number: ", #material_paths, "material attribs: ", #material_attribs)
	print "Material paths:"
	for _, p in ipairs(material_paths) do
		print(p)
	end
	print("Instance number: ", numinstance, "instance attribs: ", #instance_attribs)
end

local kb_mb = world:sub{"keyboard"}

function start_frame_sys:start_frame()
	for v in w:select "camera:in" do
		local r = v.camera
		r.viewmat = nil
		r.projmat = nil
		r.viewprojmat = nil
	end
	math3d.reset()

	-- for _, key, press in kb_mb:unpack() do
	-- 	if key == "T" and press == 0 then
	-- 		stat_material_info()
	-- 	end
	-- end
	

	-- world:print_cpu_stat()
	-- world:reset_cpu_stat()
end
