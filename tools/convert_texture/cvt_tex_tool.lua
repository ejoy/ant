package.cpath = "d:/Work/ant/projects/msvc/vs_bin/x64/Debug/?.dll"
package.path = table.concat({
    "./?.lua",
    "./packages/fileconvert/?.lua",
    "./packages/?.lua",
    "engine/?.lua",
}, ";")

local cvttex    = require "texture.convert"
local util      = require "util"
local fs        = require "filesystem.local"
local fs_util   = require "utility.fs_util"

local numarg = select('#', ...)

local assetpath
if numarg > 1 then
    assetpath = fs.path(select(2, ...))
else
    assetpath = fs.path "test/samples/unity_viking/Assets"
end

local texfiles = fs_util.list_files(assetpath, ".dds", {})
for _, f in ipairs(texfiles)do
    local lkfile = fs.path(f:string() .. ".lk")

    local lkcontent = util.rawtable(lkfile)

    local outfilepath = fs.path(f:string() .. ".bin")
    if not fs.exists(outfilepath) then
        local surcess, msg = cvttex("iOS-Metal", f, lkcontent, outfilepath)
        
        if surcess then
            print("convert success", f:string())
        else
            print("converte failed", f:string(), msg)
        end
    else
        print("file already exist:", outfilepath:string())
    end
end

local binfiles = fs_util.list_files(assetpath, ".bin", {})
local totalfilesize = 0
for _, fp in ipairs(binfiles)do
    local f = fs.open(fp, "rb")
    f:seek("end")
    totalfilesize = totalfilesize + f:tell()
    f:close()
end

print("total files converted: ", #binfiles, "total file size: ", totalfilesize)
