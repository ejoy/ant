local os = require "os"
local io = require "io"

local loads = require "tools/loadscene"
local cfg   = require "tools/ExportUnityFBXCfg"
--local lfs = require "lfs"

--$ lua -e'a=1' -e 'print(a)' script.lua
-- arg = { [-2] = "lua", [-1] = "-la",
--         [0] = "run.lua",
--         [1] = "arg1", [2] = "arg2" }
function get_cur_os_path()
    local path =io.popen"cd":read'*l'
    return path 
end 

-- default
local scene_name        = cfg.scene_name 
local package_path      = cfg.package_path 
local work_path = "" 

-- command line 
-- lua tools/exportUnityFBX.lua -i assets/scene/viking.lua -p //unity_viking/


if arg~= nil then 
    if arg[1] == nil or arg[2] == nil or arg[3] == nil or arg[4] == nil then 
        --lua exportunityfbx.lua -i scene_name -p package_path 
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

print("convert mesh start...")

local writefile = function( fname, content)
	local f = assert(io.open( fname, "w" ))
	f:write(content)
	f:close() 
	return 
end 

function strippath(filename)
	return string.match(filename, ".+/([^/]*%.%w+)$")       -- *nix system
	--return string.match(filename, “.+\\([^\\]*%.%w+)$”)   -— *win system
end

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

function file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end

local CMD_MAKE_DIR = "d:/msys64/usr/bin/mkdir -p "
local CMD_CP = "d:/msys64/usr/bin/cp "

function make_dir(path)
    local command = CMD_MAKE_DIR..'"'..path..'"'
    print("--->")
    print(command)
    os.execute( command ) 
end 

-- commandline = "/mingw64/bin/magick"
-- copy mesh to target path
local command = CMD_CP 

local PROJECT_DIR    = cfg.project_dir 
local OUT_DIR        = cfg.out_dir 

local target_path    = "test"
local target_mesh    = "test.fbx"

if file_exists(OUT_DIR) == false then 
    make_dir(OUT_DIR)
end 

for i= 1, #world[1].Meshes do   
    target_mesh = world[1].Meshes[i]
    if(target_mesh=="") then 
        print("mesh "..i.." is empty string")
    else    
        make_dir(OUT_DIR.."mesh_desc")
        print(target_mesh)
        local mesh_name = stripextension(strippath(target_mesh))
        mesh_name = mesh_name..".mesh"

        local content = "mesh_path = "..'"'..package_path..target_mesh..'"'

        writefile(OUT_DIR..'mesh_desc/'..mesh_name, content)

        target_path = stripfilename(target_mesh)
        target_mesh = stripextension(target_mesh)
        print(target_path)
        print(target_mesh)

        local path = OUT_DIR .. target_path 
        make_dir(path)    
        print(path)

        target_mesh = target_mesh..".fbx"
        print(target_mesh )

        mesh_desc = target_mesh..".lk"

        content = 'config = { flags = { invert_normal = false,flip_uv = true,ib_32 = false,},layout = { "p3|n30nIf|T|b|t20|c40",},animation = { cpu_skinning = false,ani_list = "all",load_skeleton = true,},}'
        ..'\nsourcetype = "fbx" '..'\ntype = "mesh" '
        writefile(OUT_DIR..mesh_desc,content)


        local path_table = splitpath(OUT_DIR,"/")
        print(OUT_DIR..target_mesh)

        -- copy meshes to target path
        local commandline = command..'"'..PROJECT_DIR..world[1].Meshes[i]..'"'..' '..'"'..OUT_DIR..target_mesh..'"'
        print(commandline)
        os.execute( commandline )
    end 
end 

print("convert  end")
