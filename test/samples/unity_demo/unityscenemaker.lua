local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util
local fs = require "filesystem"

local unityLoader = require "unitysceneloader"
local mc = require "mathconvert"

local unityScene = {}
unityScene.__index = unityScene


local sceneInfo = {}
sceneInfo.scale = 0.01      -- setting
sceneInfo.numEntities = 0   -- output statistics
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
    local readfile = function( fname )
        local f = assert(io.open( fname, "r" ))
        local content = f:read(256)
        f:close() 
        return load(content)()
    end 
     local context = readfile("testActiveMat.lua")
     self.curMat = CUR_MAT    
end 
function testMat:write()
    local writefile = function( fname, content)
        local f = assert(io.open( fname, "w" ))
        f:write(content)
        f:close() 
        return 
    end 
    self.curMat  = self.curMat  + 1
    local content = "CUR_MAT = ".. self.curMat 
    writefile("testActiveMat.lua",content)
end 

-- this function need move to mesh postinit，as component post action
function  get_mesh_group_id(mesh,name)
	local  groups = mesh.assetinfo.handle.groups
	for i=1,#groups do 
	   local prims = groups[i].primitives   -- group.name could be more correct 
	   if #prims >0 then 
		  if prims[1].name == name then 
		     return i 
		  end 
	   end 
	end 
end 


local function create_entity(world,name,pos,rot,scl,mesh_desc,material_desc)
    local eid = world:create_entity {
        name        = name,
        transform   = mu.srt(scl, rot, pos),
        rendermesh  = {},
        mesh        = {ref_path = fs.path ( mesh_desc ),},
        material    = {{ref_path = fs.path (material_desc),},

        can_render  = true,
        can_select  = true,
        main_view   = true,
    }

    local entity = world[eid]
    entity.mesh.group_id = get_mesh_group_id(entity.mesh,name)
end 

function strippath(filename)
	return string.match(filename, ".+/([^/]*%.%w+)$") 
end
function stripextension(filename)
	local idx = filename:match(".+()%.%w+$")
	if(idx) then
		return filename:sub(1, idx-1)
	else
		return filename
	end
end

local function to_radian(angles)
    local function radian(angle)
        return (math.pi / 180) * angle
    end

    local radians = {}
    for i=1, #angles do
        radians[i] = radian(angles[i])
    end
    return radians
end

local function makeEntityFromFbxMesh(world, scene, ent,lodFlag)
    --print("create entity ".. ent.Name)

    if ent.Mesh <= 0 then return end 

    local posScale = 1
    local scale = sceneInfo.scale 
    local name = ent.Name 
    local mesh = -1 

	local Pos ={0,0,0} 
	local Rot ={0,0,0}
	local Scl ={1,1,1}
	local Lod = 0 
	if ent.Lod  then Lod = 1 end 
	if ent.Mesh then mesh = ent.Mesh end 
	if ent.Pos then Pos = ent.Pos end 
	if ent.Rot then Rot = ent.Rot end 
    if ent.Scl then Scl = ent.Scl end 
    
    local m      = mc.getMatrixFromEuler( Rot,'YXZ')
	local Angles = mc.getEulerFromMatrix( m,'ZYX')
	Scl[1] = -Scl[1] *scale     Scl[2] = Scl[2] *scale     Scl[3] = Scl[3] *scale 
	Pos[1] = Pos[1] *posScale   Pos[2] = Pos[2] *posScale  Pos[2] = Pos[2] *posScale 

	ent.iRot = to_radian( Angles )
	ent.iPos = Pos 
    ent.iScl = Scl
    
	local len = string.len(name)
    local tag = string.sub(name,len-1,len)
    -- "Cerberus_LP.material"     --"Pipes_D160_Tileset_A.material" 
    -- "Pipes_D160_Tileset_A.material"     --"bunny.material"
    -- "assets/materials/Cerberus_LP.material"   --"gold.material"  
    --  crash
    -- "assets/materials/Concrete_Foundation_A.material"
    -- "assets/materials/Lamp_Wall_Big_Scifi_A_Emissive.material"
    -- "assets/materials/gold.material"
    local material_path =  "assets/materials/Concrete_Foundation_A.material"  
    local default_mat = material_path    -- "DefaultHDMaterial.material"

    local mesh_path = scene.Meshes[mesh]   
    
	local mesh_desc = stripextension( strippath(mesh_path) )
    mesh_desc = "//unity_demo/".."assets/mesh_desc/"..mesh_desc..".mesh"

    local numEntities = sceneInfo:getNumEntities()

    -- disable for single material test
    if numEntities <20000  then 
        if ent.NumMats ~= nil and ent.NumMats>=1 then 
            material_path = scene.Materials[ ent.Mats[1] ]
            
            if string.find(material_path,"unity_builtin_extra") then 
                material_path = default_mat
            end 
        end  
    else        
        --material_path = scene.Materials[ testMat.curMat ]
        material_path =  default_mat 
    end 
    
    local material_desc = "//unity_demo/".."assets/materials/"
    material_path = stripextension( strippath(material_path) )
    material_desc = material_desc..material_path..".material"


    if numEntities>= 8000 then 
        sceneInfo:countEntity()
        return 
    end 

    -- if mesh_desc == "//unity_demo/assets/mesh_desc/Level_01_Backdrop_Building_A.mesh" then 
    --     print("check the same mesh")
    -- end 

    create_entity(world,name,ent.iPos,ent.iRot,ent.iScl, mesh_desc, material_desc)

    sceneInfo:countEntity()
    sceneInfo:countActiveEntity()
end 

function entityWalk(world, scene, ent,lodName,lodFlag )
    local scale = 0.01
    if #ent then 
        for i=1,#ent do
            local name = ent[i].Name 
            local mesh = -1 
            local lod = 0 
            if ent[i].Lod then lod = 1 end 
            if ent[i].Mesh then mesh = ent[i].Mesh end 

            if string.find(name,"PlayerCollision") then 
                mesh = -1
            elseif string.find(name,lodName) == nil and lodFlag == 1 then 
                mesh = -1
            end 

            if mesh > 0 then 
                makeEntityFromFbxMesh(world, scene, ent[i], lod )
            end 

            if ent[i].Ent and #ent[i].Ent then 
                entityWalk(world, scene,ent[i].Ent,lodName, lod )
            end 

        end 
    end 
end     

-- "//ant.test.unitydemo/scene/scene.lua"
function unityScene.create(world,scene)	

    -- do single material check
    -- testMat:read()

    local scene = unityLoader.load(scene)
    
    local totalEntities = sceneInfo:getNumEntities()

    local entity  = scene[1].Ent  
    local sceneName = scene[1].Scene 


    entityWalk( world,scene[1],entity,"LOD00",0 )

    totalEntities = sceneInfo:getNumEntities()
    local totalActiveEntities = sceneInfo:getNumActiveEntities()
    print("Total Entities = ".. totalEntities)
    print("Total Active Entities = ".. totalActiveEntities)

    -- do check 
    -- if testMat.curMat>= 180 then 
    --     print("all material test done")
    -- end 
    -- testMat:write()
end

return unityScene 