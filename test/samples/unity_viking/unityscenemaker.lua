local math3d = import_package 'ant.math'
local ms = math3d.stack
local mu = math3d.util
local fs = require 'filesystem'

local unityLoader = require 'unitysceneloader'
local mc = require 'mathconvert'

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

local function create_entity(world, name, pos, rot, scl, meshpath, material_refpaths)    
    if #material_refpaths > 1 then
        print('check')
    end
    local eid =
        world:create_entity {
        name = name,
        transform = {
            s = scl,
            r = rot,
            t = pos
        },
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

local function makeEntityFromFbxMesh(world, scene, ent, lodFlag)
    --print("create entity ".. ent.Name)

    if ent.Mesh <= 0 then
        return
    end

    local posScale = 1
    local scale = sceneInfo.scale
    local name = ent.Name
    local mesh = -1

    local Pos = {0, 0, 0}
    local Rot = {0, 0, 0}
    local Scl = {1, 1, 1}
    local Lod = 0
    if ent.Lod then
        Lod = 1
    end
    if ent.Mesh then
        mesh = ent.Mesh
    end
    if ent.Pos then
        Pos = ent.Pos
    end
    if ent.Rot then
        Rot = ent.Rot
    end
    if ent.Scl then
        Scl = ent.Scl
    end

    local m = mc.getMatrixFromEuler(Rot, 'YXZ')
    local Angles = mc.getEulerFromMatrix(m, 'ZYX')
    Scl[1] = -Scl[1] * scale
    Scl[2] = Scl[2] * scale
    Scl[3] = Scl[3] * scale
    Pos[1] = Pos[1] * posScale
    Pos[2] = Pos[2] * posScale
    Pos[2] = Pos[2] * posScale

    ent.iRot = mu.to_radian(Angles)
    ent.iPos = Pos
    ent.iScl = Scl

    local len = string.len(name)
    local tag = string.sub(name, len - 1, len)
    -- "Cerberus_LP.material"     --"Pipes_D160_Tileset_A.material"
    -- "Pipes_D160_Tileset_A.material"     --"bunny.material"
    -- "assets/materials/Cerberus_LP.material"   --"gold.material"
    --  crash
    -- "assets/materials/Concrete_Foundation_A.material"
    -- "assets/materials/Lamp_Wall_Big_Scifi_A_Emissive.material"
    -- "assets/materials/gold.material"
	-- local material_path = 'assets/materials/Concrete_Foundation_A.material'
	local default_material_path = 'assets/materials/bunny.material' -- "DefaultHDMaterial.material"
    local mesh_path = scene.Meshes[mesh]
    if mesh_path == '' then
        return
    end

    local meshpath = fs.path'//unity_viking/assets/mesh_desc/' / fs.path(mesh_path):filename():replace_extension('mesh')

    local numEntities = sceneInfo:getNumEntities()
	local material_refpaths = {}
	local material_rootpath = fs.path '//unity_viking/assets/materials/'
	local function add_material_refpath(material_filename)
		local filepath = material_rootpath / fs.path(material_filename):filename():replace_extension('material')
		table.insert(material_refpaths, {ref_path = filepath})
	end

    -- multi materials
    if ent.NumMats ~= nil and ent.NumMats >= 1 then
        for i = 1, ent.NumMats do            
            local material_filename = scene.Materials[ent.Mats[i]]
            if material_filename:match 'unity_builtin_extra' then
                material_filename = default_material_path
			end
			
			add_material_refpath(material_filename)
        end
	else
		local function get_defautl_material_path()
			if numEntities < 20000 then
				local num_material = ent.NumMats
				if num_material and num_material >= 1 then
					local mp = scene.Materials[ent.Mats[1]]
					return mp:match "unity_builtin_extra" and default_material_path or mp
				end 
			end

			return default_material_path
		end

		add_material_refpath(get_defautl_material_path())
    end

    -- if string.find(name, 'build_gate_01') then
    --     print('check ')
    -- end

    create_entity(world, name, ent.iPos, ent.iRot, ent.iScl, meshpath, material_refpaths)

    sceneInfo:countEntity()
    sceneInfo:countActiveEntity()
end

function entityWalk(world, scene, ent, lodName, lodFlag)
    local scale = 0.01
    if #ent then
        for i = 1, #ent do
            local name = ent[i].Name
            local mesh = -1
            local lod = 0
            if ent[i].Lod then
                lod = 1
            end
            if ent[i].Mesh then
                mesh = ent[i].Mesh
            end

            if string.find(name, 'PlayerCollision') then
                mesh = -1
            elseif string.find(name, 'collider') then
                mesh = -1
            elseif string.find(name, lodName) == nil and lodFlag == 1 then
                mesh = -1
            end

            if mesh > 0 then
                makeEntityFromFbxMesh(world, scene, ent[i], lod)
            end

            if ent[i].Ent and #ent[i].Ent then
                entityWalk(world, scene, ent[i].Ent, lodName, lod)
            end
        end
    end
end

-- "//ant.test.unitydemo/scene/scene.lua"
function unityScene.create(world, scenepath)
    -- do single material check
    testMat:read()

    local sceneworld = unityLoader.load(scenepath)
    local entity = sceneworld[1].Ent
	print("load scene world name : ", sceneworld[1].Scene)

    entityWalk(world, sceneworld[1], entity, 'LOD00', 0)

    print('Total Entities:', sceneInfo:getNumEntities())
    print('Total Active Entities:', sceneInfo:getNumActiveEntities())

    -- do check
    if testMat.curMat >= 180 then
        print('all material test done')
    end
    testMat:write()
end

return unityScene
