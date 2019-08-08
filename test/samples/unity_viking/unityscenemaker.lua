local math3d = import_package 'ant.math'
local ms = math3d.stack
local mu = math3d.util
local fs = require 'filesystem'

local unityLoader = require 'unitysceneloader'
local mc = require 'mathconvert'

local assetmgr = import_package 'ant.asset'.mgr

local bgfx = require "bgfx"

local unityScene = {}
unityScene.__index = unityScene

local sceneInfo = {}
sceneInfo.scale = 1 -- setting
sceneInfo.numEntities = 0 -- output statistics
sceneInfo.numActiveEntities = 0
function sceneInfo:countEntity()
    self.numEntities = self.numEntities + 1
end
function sceneInfo:getNumEntities()
    return self.numEntities
end
function sceneInfo:countActiveEntity()
    sceneInfo.numActiveEntities = sceneInfo.numActiveEntities + 1
end
function sceneInfo:getNumActiveEntities()
    return self.numActiveEntities
end

local testMat = {}
testMat.curMat = 1
function testMat:read()
    local readfile = function(fname)
        local f = assert(io.open(fname, 'r'))
        local content = f:read(256)
        f:close()
        return load(content)()
    end
    --local context = readfile("testActiveMat.lua")
    self.curMat = 1 --CUR_MAT
end
function testMat:write()
    local writefile = function(fname, content)
        local f = assert(io.open(fname, 'w'))
        f:write(content)
        f:close()
        return
    end
    self.curMat = self.curMat + 1
    local content = 'CUR_MAT = ' .. self.curMat
    writefile('testActiveMat.lua', content)
end


local viking_assetpath = fs.path '/pkg/unity_viking/Assets'

local function fetch_mesh_path(scene, ent, lodname, lodidx)
	local mesh = ent.Mesh
    if mesh == nil or mesh <= 0 then
        return
	end

	local name = ent.Name
	if name:match 'PlayerCollision' 
	or name:match 'collider' then
		return
	end
	
	local mesh_path = scene.Meshes[mesh]
    if mesh_path == '' then
        return
	end
	
	return viking_assetpath / 'mesh_desc/' / fs.path(mesh_path):filename():replace_extension('mesh')
end

local function fetch_transform(ent)
    local posScale = 1
    local scale = sceneInfo.scale

    local Pos = ent.Pos or {0, 0, 0}
    local Rot = ent.Rot or {0, 0, 0}
    local Scl = ent.Scl or {1, 1, 1}
    local Lod = ent.Lod and 1 or 0
    
    local m = mc.getMatrixFromEuler(Rot, 'YXZ')
    local Angles = mc.getEulerFromMatrix(m, 'ZYX')
    Scl[1] = -Scl[1] * scale
    Scl[2] = Scl[2] * scale
	Scl[3] = Scl[3] * scale
	
    Pos[1] = Pos[1] * posScale
    Pos[2] = Pos[2] * posScale
    Pos[2] = Pos[2] * posScale

	return {
		s = Scl,
		r = mu.to_radian(Angles),
		t = Pos,
	}
end

local function recalculate_transform(trans)
	local scenescale = sceneInfo.scale
	local s, r, t = trans.s, trans.r, trans.t
	local translation = {t[1], t[2], t[3], t[4]}
	local rotation = mu.to_radian(r)
	local scale = {s[1] * scenescale, s[2] * scenescale, s[3] * scenescale}

	return {s=scale, r=rotation, t=translation}
    -- local posScale = 1
    -- local scale = sceneInfo.scale

    -- local m = mc.getMatrixFromEuler(trans.r, 'YXZ')
    -- local Angles = mc.getEulerFromMatrix(m, 'ZYX')

    -- local scalevalue = {}
    -- scalevalue[1] = -trans.s[1] * scale
    -- scalevalue[2] = trans.s[2] * scale
	-- scalevalue[3] = trans.s[3] * scale
    
    -- local posvalue = {}
    -- posvalue[1] = trans.t[1] * posScale
    -- posvalue[2] = trans.t[2] * posScale
    -- posvalue[3] = trans.t[3] * posScale

	-- return {
	-- 	s = scalevalue,
	-- 	r = mu.to_radian(Angles),
	-- 	t = posvalue,
	-- }
end

local default_material_path = '/pkg/ant.resources/depiction/materials/bunny.material' -- "DefaultHDMaterial.material"

local function get_material_refpath(material_filename)
    local filepath = viking_assetpath / 'materials' / fs.path(material_filename):filename():replace_extension('material')
    return {ref_path = filepath, asyn_load = true}
end

local function find_sub_list(meshlist, trans, groupname)
	local function is_list_equal(lhs, rhs)
		if #lhs == #rhs then
			for i=1, #lhs do
				if lhs[i] ~= rhs[i] then
					return nil
				end
			end
			return true
		end
	end
	for _, sm in ipairs(meshlist)do
		local t = sm.transform
		if is_list_equal(t.s, trans.s) and
		is_list_equal(t.r, trans.r) and
		is_list_equal(t.t, trans.t) then
			return sm
		end
	end
	local new = {transform = trans, groupname=groupname}
	meshlist[#meshlist+1] = new
	return new
end

local function classify_mesh_reference(scene, entitylist, parent, groups)
	for _, e in ipairs(entitylist) do
		local meshidx = e.Mesh
        if meshidx and 
        not e.Name:match "[Cc]ollider" and
		not e.Name:match "PlayerCollision" then

			local mesh_pathname = scene.Meshes[meshidx]
			if mesh_pathname ~= '' then
				local meshlist = groups[meshidx]
				if meshlist == nil then
					meshlist = {}
					groups[meshidx] = meshlist
				end
	
				local submeshlist = find_sub_list(meshlist, {s=e.Scl, r=e.Rot, t=e.Pos}, parent.Name)
				submeshlist[#submeshlist+1] = {
					material_indices = e.Mats,
					name = e.Name,
				}
			end
		end

		if e.Ent then
			classify_mesh_reference(scene, e.Ent, e, groups)
		end
	end
end

local function find_mesh_ref(meshscene, meshname)
	for _, scene in ipairs(meshscene.scenes) do
		for _, node in ipairs(scene) do
			if node.meshname == meshname then
				return node
			end
		end
	end
end

-- "//ant.test.unitydemo/scene/scene.lua"
function unityScene.create(world, scenepath)
    -- do single material check
    testMat:read()

    local sceneworld = unityLoader.load(scenepath)
    local scene = sceneworld[1]
    print("load scene world name : ", scene.Scene)

    local groups = {}
    classify_mesh_reference(scene, scene.Ent, nil, groups)

	for meshidx, meshlist in pairs(groups) do
		for _, submeshlist in ipairs(meshlist) do
			local groupname = submeshlist.groupname
			local meshpath = viking_assetpath / 'mesh_desc' / fs.path(scene.Meshes[meshidx]):filename():replace_extension('mesh')

			local trans = recalculate_transform(submeshlist.transform)

			-- try to recreate material content and setup material_refs for mesh component
			local submesh_refs = {}
			local meshscene = assetmgr.load(meshpath)
			local material_paths = {}
			for submeshidx, mesh in ipairs(submeshlist) do
				local material_indices = mesh.material_indices
				local meshref = find_mesh_ref(meshscene, mesh.name)
				if meshref == nil then
					meshref = meshscene.scenes[1][submeshidx]
				end
				if #meshref ~= #material_indices then
					print("glb mesh primitives size is not equal to material numbers", groupname, meshref.name)
				end
				
				local material_refs = {}
				for _, material_idx in ipairs(material_indices) do
					local material_filename = scene.Materials[material_idx]
					if material_filename:match 'unity_builtin_extra' then
						material_filename = default_material_path
					end
					
					local last_materialidx = #material_paths+1
					material_paths[last_materialidx] = get_material_refpath(material_filename)
					material_refs[#material_refs+1] = last_materialidx
				end
				submesh_refs[meshref.meshname] = {material_refs=material_refs, visible=true}
			end

			local eid = world:create_entity {
				name = groupname,
				transform = trans,
				rendermesh = {
					submesh_refs = submesh_refs,
				},
				material = material_paths,
				mesh = {ref_path = meshpath, asyn_load=true},
				asyn_load 	= "",
				can_render 	= true,
				can_select 	= true,
				main_view 	= true,
			}

			print("create entity:", eid, groupname)
		end
    end

    --entityWalk(world, sceneworld[1], entity, 'LOD00', 0)

    print('Total Entities:', sceneInfo:getNumEntities())
    print('Total Active Entities:', sceneInfo:getNumActiveEntities())

    -- do check
    if testMat.curMat >= 180 then
        print('all material test done')
    end
    testMat:write()
end

return unityScene
