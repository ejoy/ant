local ecs	= ...
local world = ecs.world
local w		= world.w

local assetmgr		= require "main"
local matobj		= require "matobj"
local bgfx			= require "bgfx"
local imaterial = ecs.interface "imaterial"

function imaterial.set_property(e, who, what, mattype)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	mattype = mattype or "main_queue"
	fm[mattype][who] = what
end

imaterial.load_res = assetmgr.resource
imaterial.unload_res = assetmgr.unload

function imaterial.system_attribs()
	return matobj.sa
end

local function get_palid(palname)
	return assert(matobj.color_palettes[palname], ("Invalid color palette name:%s"):format(palname))
end

function imaterial.set_color_palette(palname, coloridx, value)
	local palid = get_palid(palname)
	matobj.rmat.color_palette_set(palid, coloridx, value)
end

function imaterial.get_color_palette(palname, coloridx)
	local palid = get_palid(palname)
	return matobj.rmat.color_palette_get(palid, coloridx)
end

function imaterial.resource(e)
	w:extend(e, "material:in")
	return assetmgr.resource(e.material)
end

function imaterial.set_state(e, state)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	return fm.main_queue:set_state(bgfx.make_state(state))
end

local ms = ecs.system "material_system"

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

	local s = matobj.rmat.stat()
	print("material cobject, attrib number:", s.attrib_num, "attrib cap:", s.attrib_cap)
end

local DEBUG_MATERIAL_ATTRIBUTES<const> = false
function ms:component_init()
	w:clear "material_result"

	for e in w:select "INIT material:in material_result:new" do
		e.material_result = imaterial.load_res(e.material)
		if DEBUG_MATERIAL_ATTRIBUTES then
			w:extend(e, "name?in eid:in")
			print("created material entity:", e.eid, e.name, e.material)
		end
	end
end

function ms:entity_remove()
	if DEBUG_MATERIAL_ATTRIBUTES then
		for e in w:select "REMOVED material:in name?in eid:in" do
			print("removed material entity:", e.eid, e.name, e.material)
		end
	end
end

local counter = 0
local itimer = ecs.require "ant.timer|timer_system"
function ms:end_frame()
	if DEBUG_MATERIAL_ATTRIBUTES then
		counter = counter + itimer.delta()
		if counter >= 1000 then
			print("material entity count:", w:count "material")
			stat_material_info()
			counter = 0
		end
	end
end