local os = require "os"
local io = require "io"


--package.path = package.path..";./test/samples/unity_demo/?.lua;./test/samples/unity_demo/?/?.lua;"

local loads = require "tools/loadscene"
local cfg   = require("tools/ExportConvUnityMatCfg")
--local lfs = require "lfs"

--$ lua -e'a=1' -e 'print(a)' script.lua
-- arg = { [-2] = "lua", [-1] = "-la",
--         [0] = "run.lua",
--         [1] = "arg1", [2] = "arg2" }

--lua tools/exportConvUnityMat.lua -i scene/sample.lua -p ///Unity_demo/
-- env 
-- /package
--  - tools
--  - assets/scene
--  - assets/mesh 
--  do lua convert 

function get_cur_script_path()
    local info = debug.getinfo(1, "S")  -- 第二个参数 "S" 表示仅返回 source,short_src等字段， 其他还可以 "n", "f", "I", "L"等 返回不同的字段信息

    for k,v in pairs(info) do
        print(k, ":", v)
    end

    local path = info.source
    path = string.sub(path, 2, -1)      -- 去掉开头的"@"
    path = string.match(path, "^.*/")   -- 捕获最后一个 "/" 之前的部分 就是我们最终要的目录部分
    return path 
end 

function get_cur_os_path()
    local path =io.popen"cd":read'*l'
    return path 
end 

-- change this by using commandline 
-- local scene_name        = "assets/scene/viking.lua" 
-- local package_path      = "//unity_viking/"
local scene_name        = cfg.scene_name 
local package_path      = cfg.package_path 
local work_path = "" 

if arg~= nil then 
    if arg[1] == nil or arg[2] == nil or arg[3] == nil or arg[4] == nil then 
        print("usage: lua tools/ExportConvUnityMat.lua -i scene_path/scene.lua -p package_path")   
        return 
    end 
    if arg[2]  then 
        scene_name = arg[2] 
    end 
    if arg[4]  then 
        package_path = arg[4]
    end 
    print(arg[-1]..' '..arg[0]..' '..arg[1]..' '..arg[2]..' '..arg[3]..' '..arg[4])
else
    print("usage: lua tools/ExportConvUnityMat.lua -i scene_path/scene.lua -p package_path")   
    work_path = get_cur_os_path()  
    scene_name = work_path.."/"..scene_name 
end 


print("scene  name = ",scene_name)
print("output path = ",package_path)

local world = loads:loadUnityScene( scene_name ) 

if world == nil then
    print("invalid scene")
    return 
end 
print("get a world = ",world[1].Scene)


print("\nconvert start ...... \n ")

function stripfilename(filename)
    return string.match(filename, "(.+)/[^/]*%.%w+$") 
end 

function stripextension(filename)
	local idx = filename:match(".+()%.%w+$")
	if(idx) then
		return filename:sub(1, idx-1)
	else
		return filename
	end
end

function strippath(filename)
	return string.match(filename, ".+/([^/]*%.%w+)$")       -- *nix system
	--return string.match(filename, “.+\\([^\\]*%.%w+)$”)   -— *win system
end


function splitpath(path,sep)
    local start = 1
    local index = 1
    local array = {}
    while true do 
        local last = string.find(path,sep,start)
        if not last then 
            array[index] = string.sub(path,start,string.len(path))
            break
        end 
        array[index] = string.sub(path,start,last-1)
        start = last+ string.len(sep)
        index = index + 1
    end 
    return array 
end 


-- this function doesn't work
function file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end

function make_dir(path)
    local command = "d:/msys64/usr/bin/mkdir -p "..path 
    print("--->")
    print(command)
    os.execute( command ) 
end 

function select_valid_texture( world )
    local NumTextures = #world.Textures
    local texture =''

    for i= 1 , NumTextures do           
        texture = world.Textures[i]
        if texture ~= '' then 
            return texture 
        end 
    end 
end 


local CMD_CONVERT = "d:/msys64/mingw64/bin/magick "
local command = CMD_CONVERT

local PROJECT_DIR         = cfg.project_dir 
local OUT_DIR             = cfg.out_dir 
local TARGET_TEXTURE_TYPE = cfg.target_texture_type
local TARGET_TEXDESC_TYPE = cfg.target_texdesc_type 
local TARGET_MATERIAL_TYPE = cfg.target_material_type 

local target_path    = OUT_DIR 
local target_texture = TARGET_TEXTURE_TYPE
local target_texdesc = TARGET_TEXDESC_TYPE 


make_dir(OUT_DIR)

local texdesc_path = OUT_DIR.."texture_desc"
--if file_exists(texdesc_path) then 
    make_dir(texdesc_path)
--end 

local writefile = function( fname, content)
	local f = assert(io.open( fname, "w" ))
	f:write(content)
	f:close() 
	return 
end 
 

if cfg.gen_tex == 1 then 

    print("step 1: convert textures ----------------------------------------------------")
    local NumTextures = #world[1].Textures
    print("NumTextures = "..NumTextures)

    for i= 1 , NumTextures do   
        target_texture = world[1].Textures[i]

        if target_texture == '' then 
            target_texture = select_valid_texture( world[1] )
            world[1].Textures[i] = target_texture      -- overwrite 
        end 
        
        print(target_texture)
        target_path = stripfilename(target_texture)
        target_texture = stripextension(target_texture)
        print(target_path)
        print(target_texture)

        local path = '"'.. OUT_DIR .. target_path ..'"' 
        make_dir(path)    
        print(path)

        target_texture = target_texture..TARGET_TEXTURE_TYPE        --".dds"
        print(target_texture)


        local path_table = splitpath(OUT_DIR,"/")
        print(OUT_DIR..target_texture)

        --1. convert image 
        --  ( image1 -filter lanczos -resize WxH -unsharp 0xsigma ) image2 -alpha off -compose copy_opacity -composite result
        local commandline = command..'"'..PROJECT_DIR..world[1].Textures[i]..'"'..' '..'-resize 2048x2048'..' '..'"'..OUT_DIR..target_texture..'"'
        print(commandline)
        os.execute( commandline )

        -- 2. generate .texture 
        local texdesc_name = stripextension(strippath(target_texture))
        texdesc_name = texdesc_name..TARGET_TEXDESC_TYPE            --".texture"
        --path = "//pbr/assets/textures/pbr/bolonga_lod.dds"
        local is_normal = " normalmap 	= false\n"
        if string.find(target_texture,"_Normal") then      
            is_normal =" normalmap 	= true\n"
        end 

        local content = " path =" ..' "'..package_path..target_texture..'"\n'
            ..' sampler = {\n'
            ..'   U = "MIRROR",\n'
            ..'   V = "MIRROR",\n'
            ..'   MIN = "LINEAR",\n'
            ..'   MAG = "LINEAR",\n'	
            .." }\n"
            .." sRGB 		= true\n"
            ..is_normal 

        writefile(OUT_DIR..'texture_desc/'..texdesc_name, content)
    end 
    print(" ")

end 


if cfg.gen_mat == 1 then 

print("step 2: convert materials --------------------------------------------------")
local material_path = OUT_DIR.."materials"
--if file_exists(material_path) then 
    make_dir(material_path)
--end 

function texture_def(name,stage,texture_desc)
    local context ="    ".. name .. ' = { type="texture",name='..'"'..name..'",'
    ..'stage = '..stage..','
    ..'ref_path="'..texture_desc..'"'..'},\n'
    return context
end 

function uniform_def(name,value)
    local context ="    ".. name .. ' = { type="v4",name='..'"'..name..'",'
    ..'default={'..value[1]..','..value[2]..','..value[3]..','..value[4]..'}'..'},\n'
    return context
end 

function GetMatProperties(Textures,MetaData)
    if string.find( MetaData.Name,"planet.mat") then 
        print("check")
    end 
    local MatProp = {}
    if MetaData._BaseColorMap0 ~= nil or MetaData._BaseColor0 ~=nil then 
        MatProp.MultiLayer = 1
        MatProp.BaseColorMap = Textures[MetaData._BaseColorMap0]
        MatProp.NormalMap = Textures[MetaData._NormalMap0]
        MatProp.MaskMap = Textures[MetaData._MaskMap0]
        if MatProp.BaseColorMap then  print("Albedo = ".. MatProp.BaseColorMap ) else MatProp.BaseColorMap = "/Default/DefaultA.dds" end 
        if MatProp.NormalMap then print("NormalMap = ".. MatProp.NormalMap ) else MatProp.NormalMap = "/Default/DefaultN.dds" end 
        if MatProp.MaskMap then print("MaskMap = ".. MatProp.MaskMap ) else MatProp.MaskMap = "/Default/DefaultM.dds" end 

        MatProp.BaseColor = MetaData._BaseColor0 
        MatProp.Metallic  = MetaData._Metallic0
        MatProp.Smoothness = MetaData._Smoothness0
        MatProp.LayerMaskMap = MetaData._LayerMaskMap
    else       
        MatProp.BaseColorMap = Textures[MetaData._BaseColorMap]
        MatProp.NormalMap = Textures[MetaData._NormalMap]
        MatProp.MaskMap = Textures[MetaData._MaskMap]

        if MatProp.BaseColorMap == nil and MatProp.NormalMap == nil and MatProp.MaskMap == nil then 
            MatProp.BaseColorMap = Textures[MetaData._MainTex]
            MatProp.NormalMap    = Textures[MetaData._BumpMap]
            MatProp.MaskMap      = Textures[MetaData._SpecGlossMap]
            MatProp.AlphaCutoff = MetaData._Cutoff
        end 

        if MatProp.BaseColorMap then  print("Single Albedo = ".. MatProp.BaseColorMap ) else MatProp.BaseColorMap = "/Default/DefaultA.dds"  end 
        if MatProp.NormalMap then print("Single NormalMap = ".. MatProp.NormalMap ) else MatProp.NormalMap = "/Default/DefaultN.dds" end 
        if MatProp.MaskMap then print("Single MaskMap = ".. MatProp.MaskMap ) else MatProp.MaskMap = "/Default/DefaultM.dds" end 

        MatProp.BaseColor = MetaData._BaseColor 
        MatProp.Metallic  = MetaData._Metallic
        MatProp.Smoothness = MetaData._Smoothness

        if MatProp.BaseColor == nil and MatProp.Metallic == nil and MatProp.Smoothness == nil then 
            -- specular flow 
            MatProp.BaseColor = MetaData._Color 
            MatProp.Metallic = 0                     
            MatProp.Smoothness = MetaData._Glossiness 
            MatProp.SmoothnessAorS = MetaData._SmoothnessTextureChannel  -- Specular Alpha,0,Albedo Alpha,1 
        end 

        if MatProp.BaseColor == nil then MatProp.BaseColor = {1,1,1,1} end 
        if MatProp.Metallic == nil then MatProp.Metallic = 0 end 
        if MatProp.Smoothness == nil then MatProp.Smoothness = 0.5 end 

        MatProp.Smoothness = MatProp.Smoothness + 0.3
        
    end 
    return MatProp 
end 

local NumMaterials = #world[1].MaterialMetaDatas
print("NumMaterials = "..NumMaterials )
for i= 1, NumMaterials do  
    local MetaData =  world[1].MaterialMetaDatas[i]
    print(MetaData.Name)

    local MatProp = GetMatProperties(world[1].Textures,MetaData)

    local BaseColorMap = stripextension(strippath( MatProp.BaseColorMap ))
    local NormalMap    = stripextension(strippath( MatProp.NormalMap ))
    local MaskMap      = stripextension(strippath( MatProp.MaskMap ))

    BaseColorMap = package_path.."assets/texture_desc/"..BaseColorMap..TARGET_TEXDESC_TYPE 
    NormalMap    = package_path.."assets/texture_desc/"..NormalMap..TARGET_TEXDESC_TYPE 
    MaskMap      = package_path.."assets/texture_desc/"..MaskMap..TARGET_TEXDESC_TYPE 

    CubeMap      = package_path.."assets/textures/bolonga.texture"
    CubeIrr      = package_path.."assets/textures/bolonga_irr.texture"
    --texdesc_name = texdesc_name..TARGET_TEXDESC_TYPE            --".texture"

    local content = 'shader = {\n'
    ..'   vs = "'..package_path..'assets/shader/pbr/vs_mesh_pbr",\n'
    ..'   fs = "'..package_path..'assets/shader/pbr/fs_mesh_pbr",\n'
    ..'}\n'

    ..'state = {\n'
    ..'   CULL = "CW",\n'
    ..'   WRITE_MASK = "RGBAZ",\n'
    ..'   DEPTH_TEST = "LESS"\n'
    ..'}\n'
    
    ..'properties = {\n'
   
    ..'  textures = {\n'
    ..texture_def('s_basecolor',0, BaseColorMap  )
    ..texture_def('s_normal',1, NormalMap )
    ..texture_def('s_metallic',2, MaskMap )
    ..texture_def('s_texCube',3,CubeMap)
    ..texture_def('s_texCubeIrr',9,CubeIrr)
    ..'  },\n'
    ..'  uniforms = {\n'
    ..uniform_def('u_params',{0,1,MatProp.Metallic,MatProp.Smoothness})
    ..uniform_def('u_diffuseColor', MatProp.BaseColor )
    ..uniform_def('u_specularColor',{1,0,0,1})
    ..'  },\n'
       
    ..'}\n'

    if string.find(MetaData.Name,"builtin_extra") then 
        MetaData.Name = "//DefaultMaterial.mat"    
    end 

    local material_name = stripextension(strippath(MetaData.Name))
    material_name = material_name..TARGET_MATERIAL_TYPE            --".material"

    writefile(OUT_DIR..'materials/'..material_name, content)
end 
print(" ")

end 


print("convert end")
