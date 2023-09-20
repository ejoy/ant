local ecs   = ...
local world = ecs.world
local w     = world.w

local assetmgr = import_package "ant.asset"

local dm = ecs.system "debug_material_system"

local counter = 0
local itimer = ecs.require "ant.timer|timer_system"

local function stat_material_info(verbose)
	local materials = {}
	local instances = {}
	for e in w:select "material:in render_object:in filter_material:in" do
		for _, mi in pairs(e.filter_material) do
			if instances[mi] == nil then
				instances[mi] = true
			end
		end

		local r = assetmgr.resource(e.material)
		materials[r.object] = e.material
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
	if verbose then
		print "Material paths:"
		for _, p in ipairs(material_paths) do
			print(p)
		end
	end
	print("Instance number: ", numinstance, "instance attribs: ", #instance_attribs)

	print("NEED material.core provide stat info")
	--print("material cobject, attrib number:", s.attrib_num, "attrib cap:", s.attrib_cap)
end

function dm.component_init()
    for e in w:select "INIT material eid:in" do
        w:extend(e, "eid:in")
        print("created material entity:", e.eid, e.material)
    end
end

function dm:entity_remove()
    for e in w:select "REMOVED material:in eid:in" do
        print("removed material entity:", e.eid, e.material)
    end
end

function dm:end_frame()
    counter = counter + itimer.delta()
    if counter >= 1000 then
        print("material entity count:", w:count "material")
        stat_material_info()
        counter = 0
    end
end