local math3d = import_package 'ant.math'
local ms = math3d.stack
local mu = math3d.util
local fs = require 'filesystem'

local unityLoader = require 'unitysceneloader'
local mc = require 'mathconvert'

local assetmgr = import_package 'ant.asset'.mgr

local unityScene = {}
unityScene.__index = unityScene

local sceneInfo = {}
sceneInfo.scale = 0.01 -- setting
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

-- this function need move to mesh postinit，as component post action
-- function get_mesh_group_id(mesh, name)
--     local groups = mesh.assetinfo.handle.groups
--     for i = 1, #groups do
--         local prims = groups[i].primitives -- group.name could be more correct
--         if #prims > 0 then
--             if prims[1].name == name then
--                 return i
--             end
--         end
--     end
-- end

local function create_entity(world, name, trans, meshpath, material_refpaths)    
    if #material_refpaths > 1 then
        print('check')
    end
    return
        world:create_entity {
        name = name,
        transform = trans,
        can_render = true,
        can_select = true,
        material = {
            content = material_refpaths
        },
        mesh = {
            ref_path = meshpath,
        },
        main_view = true
    }

    -- local entity = world[eid]
    -- entity.mesh.group_id = get_mesh_group_id(entity.mesh, name)
    -- if entity.mesh.group_id == nil then
    --     if string.find(name, 'pf_') then
    --         local pf_name = string.sub(name, 4, -1)
    --         entity.mesh.group_id = get_mesh_group_id(entity.mesh, pf_name)
    --     end
    -- --assert(false,"entity name not equal mesh")
    -- end
end

-- function strippath(filename)
--     return string.match(filename, '.+/([^/]*%.%w+)$')
-- end
-- function stripextension(filename)
--     local idx = filename:match('.+()%.%w+$')
--     if (idx) then
--         return filename:sub(1, idx - 1)
--     else
--         return filename
--     end
-- end

-- local function to_radian(angles)
--     local function radian(angle)
--         return (math.pi / 180) * angle
--     end

--     local radians = {}
--     for i = 1, #angles do
--         radians[i] = radian(angles[i])
--     end
--     return radians
-- end

local viking_assetpath = fs.path '//unity_viking/Assets'

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
    local posScale = 1
    local scale = sceneInfo.scale

    local m = mc.getMatrixFromEuler(trans.r, 'YXZ')
    local Angles = mc.getEulerFromMatrix(m, 'ZYX')

    local scalevalue = {}
    scalevalue[1] = -trans.s[1] * scale
    scalevalue[2] = trans.s[2] * scale
	scalevalue[3] = trans.s[3] * scale
    
    local posvalue = {}
    posvalue[1] = trans.p[1] * posScale
    posvalue[2] = trans.p[2] * posScale
    posvalue[2] = trans.p[2] * posScale

	return {
		s = scalevalue,
		r = mu.to_radian(Angles),
		t = posvalue,
	}
end

local default_material_path = '//ant.resources/depiction/materials/bunny.material' -- "DefaultHDMaterial.material"

local function get_defautl_material_path(scene, ent)
	local numEntities = sceneInfo:getNumEntities()
	if numEntities < 20000 then
		local num_material = ent.NumMats
		if num_material and num_material >= 1 then
			local mp = scene.Materials[ent.Mats[1]]
			return mp:match "unity_builtin_extra" and default_material_path or mp
		end 
	end

	return default_material_path
end

local function get_material_refpath(material_filename)
    local filepath = viking_assetpath / 'materials' / fs.path(material_filename):filename():replace_extension('material')
    return {ref_path = filepath}
end

local function fetch_material_paths(scene, ent)
    -- "Cerberus_LP.material"     --"Pipes_D160_Tileset_A.material"
    -- "Pipes_D160_Tileset_A.material"     --"bunny.material"
    -- "assets/materials/Cerberus_LP.material"   --"gold.material"
    --  crash
    -- "assets/materials/Concrete_Foundation_A.material"
    -- "assets/materials/Lamp_Wall_Big_Scifi_A_Emissive.material"
    -- "assets/materials/gold.material"
	-- local material_path = 'assets/materials/Concrete_Foundation_A.material'

	local material_refpaths = {}    
    
    -- multi materials
    if ent.NumMats then
        for i = 1, ent.NumMats do
            local material_filename = scene.Materials[ent.Mats[i]]
            if material_filename:match 'unity_builtin_extra' then
                material_filename = default_material_path
			end
			material_refpaths[#material_refpaths+1] = get_material_refpath(material_filename)
        end
    else
        material_refpaths[#material_refpaths+1] = get_material_refpath(get_defautl_material_path(scene, ent))
	end
	
	return material_refpaths
end

local function makeEntity(world, scene, ent, lodname, lodidx)
    --print("create entity ".. ent.Name)
	
    -- local len = string.len(name)
    -- local tag = string.sub(name, len - 1, len)


    -- if string.find(name, 'build_gate_01') then
    --     print('check ')
    -- end

	local mesh_path = fetch_mesh_path(scene, ent, lodname, lodidx)
	if mesh_path then
		local trans = fetch_transform(ent)
		local material_paths = fetch_material_paths(scene, ent)
		create_entity(world, ent.Name, trans, mesh_path, material_paths)
	end

    sceneInfo:countEntity()
    sceneInfo:countActiveEntity()
end

local function entityWalk(world, scene, entlist, lodName, lodFlag)
	local scale = 0.01
	for _, ent in ipairs(entlist) do
		makeEntity(world, scene, ent, lodName, lodFlag)

		if ent.Ent then
			entityWalk(world, scene, ent.Ent, lodName, lodFlag)
		end
	end

end

local function classify_mesh_reference(scene, entitylist, parent, groups)
	for _, e in ipairs(entitylist) do
		local meshidx = e.Mesh
        if meshidx and 
        not e.Name:match "[Cc]ollider" and
        not e.Name:match "PlayerCollision" then
			local group = groups[assert(parent).Name]
			if group == nil then
				group = {}
				groups[parent.Name] = group
			end

			local meshlist = group[meshidx]
			if meshlist == nil then
				meshlist = {}
				group[meshidx] = meshlist
			end

			meshlist[#meshlist+1] = {
				transform = {
					s=e.Scl, r=e.Rot, t=e.Pos,
				},
				material_indices = e.Mats,
				name = e.Name,
			}

			assert(e.Ent == nil)
			return true
		end

		if e.Ent then
			if classify_mesh_reference(scene, e.Ent, e, groups) then
				return true
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

    for groupname, group in pairs(groups) do
        for meshidx, meshlist in pairs(group)do
            local mesh_pathname = scene.Meshes[meshidx]
            if mesh_pathname ~= '' then
                local meshpath = viking_assetpath / 'mesh_desc/' / fs.path(mesh_pathname):filename():replace_extension('mesh')

                assert(#meshlist > 1)
                local trans = recalculate_transform(meshlist[1].transform)

                -- try to recreate material content
                local meshscene = assetmgr.load(meshpath)
                local function find_mesh_node(meshscene, nodename)
                    local function find_mesh_node_ex(scenenodes)
                        for _, nodeidx in ipairs(scenenodes) do
                            local node = meshscene.nodes[nodeidx+1]
                            if node.name == nodename then
                                return node
                            end

                            if node.children then
                                return find_mesh_node_ex(node.children)
                            end
                        end
                    end

                    return find_mesh_node_ex(meshscene.scenes[meshscene.scene+1].nodes)
                end

                local material_paths = {}
                for _, mesh in ipairs(meshlist) do
                    local meshnode = find_mesh_node(meshscene, mesh.name)
                    local material_indices = mesh.material_indices
                    assert(#meshnode.primitives == #material_indices)
                    for idx, material_idx in ipairs(material_indices) do
                        local material_filename = scene.Materials[material_idx]
                        if material_filename:match 'unity_builtin_extra' then
                            material_filename = default_material_path
                        end

                        local prim = meshnode.primitives[idx]
                        prim.material = #material_paths -- meshscene's index is base on 0

                        material_paths[#material_paths+1] = get_material_refpath(material_filename)
                    end
                end

                local eid = world:create_entity {
                    name = groupname,
                    transform = trans,
                    mesh = {
                        ref_path = meshpath,
                    },
                    material = {
                        content = material_paths,
                    },
                    can_render = true,
                    can_select = true,
                    main_view = true,
                }

                print("create entity:", eid, groupname)
            end
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
