local os = require "os"
local io = require "io"

local loads = require "tools/loadscene"
--local lfs = require "lfs"

--$ lua -e'a=1' -e 'print(a)' script.lua
-- arg = { [-2] = "lua", [-1] = "-la",
--         [0] = "run.lua",
--         [1] = "arg1", [2] = "arg2" }

local scene_name = arg[1] 

if  scene_name == nil then 
  scene_name = "scene/scene.lua" 
end 

local world = loads:loadUnityScene( scene_name ) 

if world == nil then
    print("invalid scene")
    return 
end 

print("convert start...")

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

function make_dir(path)
    local command = "d:/msys64/usr/bin/mkdir -p "..path 
    print("--->")
    print(command)
    os.execute( command ) 
end 


-- commandline = "/mingw64/bin/magick"
local command = "d:/msys64/mingw64/bin/magick "

local project_dir    = "d:/fps/fpssample/"
local out_dir        = "d:/fps/demo/"
local target_path    = "test"
local target_texture = "test.dds"

if file_exists(out_dir) == false then 
    make_dir(out_dir)
end 

for i= 1, #world[1].Textures do   
    target_texture = world[1].Textures[i]
    print(target_texture)
    target_path = stripfilename(target_texture)
    target_texture = stripextension(target_texture)
    print(target_path)
    print(target_texture)

    local path = out_dir .. target_path 
    make_dir(path)    
    print(path)

    target_texture = target_texture..".dds"
    print(target_texture)


    local path_table = splitpath(out_dir,"/")
    -- for i=1,#path_table do 
    --  if lfs.dir(target_dir) then
    --    make_dir(target_dir..target_texture)
    --  end 
    -- end 

    print(out_dir..target_texture)

    --convert ( image1 -filter lanczos -resize WxH -unsharp 0xsigma ) image2 -alpha off -compose copy_opacity -composite result
    local commandline = command..project_dir..world[1].Textures[i]..' '..'-resize 512x512'..' '..out_dir..target_texture
    print(commandline)
    os.execute( commandline )
end 

print("convert end")
