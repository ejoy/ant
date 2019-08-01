package.path = "./?.lua;libs/?.lua;libs/?/?.lua;packages/glTF/?.lua"
package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

local fs = require "filesystem.local"

local rootdir = fs.path "."

local util = require "tools.fbx2gltf.util"

local excludes = {
	[".repo"]=true, 
	[".git"]=true, 
	[".vs"]=true, 
	[".vscode"]=true,
	["3rd"]=true
}

local files = {}
util.list_files(rootdir, ".fbx", excludes, files)

local fbxfile_mark = {}
for _, f in ipairs(files) do
	local fn = f:filename()
	if fbxfile_mark[fn] then
		print("duplicate file:", f:string(), fn:string())
	else
		fbxfile_mark[fn:string()] = true
	end	
end

local meshfiles = {}
util.list_files(rootdir, ".mesh", excludes, meshfiles)

for _, mf in ipairs(meshfiles) do
	local c = util.raw_table(mf)
	local mp = c.mesh_path
	local fn = fs.path(mp):filename():string()
	fbxfile_mark[fn] = nil
end

print("has fbx file, but not have mesh file:")
for name in pairs(fbxfile_mark)do
	print(name)
end