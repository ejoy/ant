package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

package.path = "engine/?.lua;packages/?.lua"

local fs = require "filesystem.local"

local fs_util   = require "utility.fs_util"
local stringify = require "utility.stringify"

local viking_path   = fs.path "test/samples/unity_viking"
local res_bin_path  = fs.path "d:/Work/ant/packages/resources.binary"

local function write_table_content(c, filepath)
    local r = stringify(c, true, true)
    local glblk = fs.open(filepath, "w")
    glblk:write(r)
    glblk:close()
end

local function remove_files()
    local files = fs_util.list_files(viking_path, ".dds|.fbx", {})

    for _, ff in ipairs(files) do
        local lkfile = fs.path(ff:string() .. ".lk")
        if fs.exists(lkfile) then
            print("removing:", lkfile:string())
            fs.remove(lkfile)
        end
        
        print("removing:", ff:string())
        fs.remove(ff)
    end

end

local function move_glb_to_resource_binary()
    local glb_files = fs_util.list_files(viking_path, ".glb", {})

    local resbin_viking_asset_path = res_bin_path / "test/unity_viking"
    for _, glbfile in ipairs(glb_files) do
        local local_respath = fs.path(glbfile:string():sub(#viking_path:string()+2))
        local lkfile = fs.path(glbfile:string() .. ".lk")
        local local_lkfile = fs.path(local_respath:string() .. ".lk")
    
        local function cut_file(src, dst)
            print("copying file:", src:string(), dst:string())

            if fs.exists(src) then
                fs.create_directories(dst:parent_path())
                fs.copy_file(src, dst, true)
                print("removing file:", src:string())
                fs.remove(src)
            end
        end

        cut_file(lkfile, resbin_viking_asset_path / local_lkfile)
        cut_file(glbfile, resbin_viking_asset_path / local_respath)
    end

    local mesh_files = fs_util.list_files(viking_path, ".mesh", {})

    local viking_pkgname = "/pkg/unity_viking/"
    local new_pkgname = "/pkg/ant.resources.binary/test/unity_viking/"
    for _, mf in ipairs(mesh_files) do
        local c = fs_util.raw_table(mf)
        local resname = c.mesh_path:match(viking_pkgname .. "(.+%.glb)$")
        if resname then
            c.mesh_path = new_pkgname .. resname
            print("reseting new path:", c.mesh_path)
            write_table_content(c, mf)
        end
    end
end

remove_files()
move_glb_to_resource_binary()
