package.cpath = "projects/msvc/vs_bin/Debug/?.dll"
package.path = table.concat({
    "./?.lua",
    "tools/refactor_asset/?.lua",
    "engine/?.lua",
    "packages/?.lua"
}, ";")

local fs        = require "filesystem.local"
local fs_util   = require "utility.fs_util"
local util      = require "util"

local cwd       = fs.path ""

local exculdes = {
    ["3rd"]     = true, 
    [".repo"]   = true, 
    [".cache"]  = true, 
    [".git"]    = true,
    [".vs"]     = true,
    [".vscode"] = true,
}

local meshfiles = fs_util.list_files(cwd, ".mesh", exculdes)

local lkfiles = {}
for _, mf in ipairs(meshfiles)do
    local mc = fs_util.raw_table(mf)
    local meshpath = util.to_local_path(fs.path(mc.mesh_path))
    if fs.exists(meshpath) then
        local meshlkpath = fs.path(meshpath:string() .. ".lk")
        if fs.exists(meshlkpath) then
            local lkc = fs_util.raw_table(meshlkpath)
            for k, v in pairs(lkc) do
                assert(mc[k] == nil)
                mc[k] = v
            end

            util.save_raw_table(mf, mc)
            lkfiles[#lkfiles+1] = meshlkpath
        else
            print("mesh lk path not exits:", meshlkpath:string())
        end
    else
        print("mesh path not exist:", mf:string(), mc.mesh_path)
    end
end

local textures = fs_util.list_files(cwd, ".texture", exculdes)

for _, tf in ipairs(textures) do
    local tc = fs_util.raw_table(tf)
    local texpath = util.to_local_path(fs.path(tc.path))
    if fs.exists(texpath) then
        local texlkpath = fs.path(texpath:string() .. ".lk")
        if fs.exists(texlkpath) then
            local lkcontent = fs_util.raw_table(texlkpath)
            for k, v in pairs(lkcontent) do
                tc[k] = v
            end

            util.save_raw_table(tf, tc)
            lkfiles[#lkfiles+1] = texlkpath
        else
            print("texture lk path not found:", texpath:string())
        end
    else
        print("texture path is not exist:", tf:string(), tc.path)
    end
end

for _, lkfile in ipairs(lkfiles) do
    fs.remove(lkfile)
end
