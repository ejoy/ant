package.cpath = "d:/Work/ant/projects/msvc/vs_bin/x64/Debug/?.dll"
package.path = "./?.lua;./packages/fileconvert/texture/?.lua;./packages/fileconvert/?.lua;engine/?.lua"

local cvttex = require "convert"
local util = require "util"
local fs = require "filesystem.local"

local resdir = fs.path "packages/fileconvert/texture/resources"

local sourcefile = resdir / "build_boat_01_a.dds"
local lkfile = fs.path(sourcefile:string() .. ".lk")

local lkcontent = util.rawtable(lkfile)

local surcess, msg = cvttex("Window-D3D11", sourcefile, lkcontent, resdir / "test.tex.bin")

if surcess then
    print("convert success", msg)
else
    print("converte failed", msg)
end