package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

package.path = "engine/?.lua;packages/?.lua"

local fs                    = require "filesystem.local"
local fs_util               = require "utility.fs_util"

local stringify             = require "utility.stringify"
local subprocess            = require "subprocess"

local viking_path           = fs.path "test/samples/unity_viking"
local viking_assetpath      = viking_path / "Assets"

local localviking_assetpath = fs.path "D:/Code/github/Viking-Village"

local res_binary_path       = fs.path "D:/Work/ant/packages/resources.binary"
local newtex_assetpath      = res_binary_path / "test/unity_viking"

fs.create_directories(newtex_assetpath)

local mark_texfile = {}

local function write_table_content(c, filepath)
    local r = stringify(c, true, true)
    local glblk = fs.open(filepath, "w")
    glblk:write(r)
    glblk:close()
end

local convert_jobs = {}

local function convert_tif_to_png(tif_file, png_file)
    if not fs.exists(png_file) then
        local commands = {
            "d:/Program Files/ImageMagick-7.0.8-Q8/magick.exe",
            tif_file:string() .. "[0]", png_file:string(),
        }
        convert_jobs[#convert_jobs+1] = {
            process = subprocess.spawn(commands),
            commands = commands,
        }
    end
end

local function wait_jobs()
    for _, job in ipairs(convert_jobs) do
        local e = job.process:wait()
        if e ~= 0 then
            print("convert failed:", job.src_file:string(), job.dst_file:string())
        else
            print("convertd success:", job.src_file:string(), job.dst_file:string())
        end
    end
end

local function copy_files()
    local texfiles         = fs_util.list_files(viking_assetpath, ".dds", {})
    
    for _, tf in ipairs(texfiles) do
        local src_lkfile = fs.path(tf:string() .. ".lk")
        local local_assetpath = fs.path(tf:string():sub((#viking_path:string())+2))
        local src_assetpath = (localviking_assetpath / local_assetpath):replace_extension ".tif"
    
        local dst_assetpath = newtex_assetpath / local_assetpath
    
        if fs.exists(src_assetpath) then
            local tif_path = fs.path(src_assetpath):replace_extension ".tif"
            dst_assetpath = fs.path(dst_assetpath):replace_extension ".png"
    
            if not fs.exists(dst_assetpath) then
                fs.create_directories(dst_assetpath:parent_path())    
                print("add tif convert:", tif_path:string(), dst_assetpath:string())
                convert_tif_to_png(tif_path, dst_assetpath)
            end

            local dst_lkpath = fs.path(dst_assetpath:string() .. ".lk")
            fs.copy_file(src_lkfile, dst_lkpath, true)
        else
            local dst_lkfile = fs.path(dst_assetpath:string() .. ".lk")
            fs.create_directories(dst_lkfile:parent_path())
            
            local function copy_lkfile()
                assert(tf:equal_extension "dds")
                assert(fs.exists(src_lkfile))
                local lkcontent = fs_util.raw_table(src_lkfile)
                if lkcontent.compress.window then
                    print("remove window compress attribute:", src_lkfile:string())
                    lkcontent.compress.window = nil
                    write_table_content(lkcontent, dst_lkfile)
                else
                    fs.copy_file(src_lkfile, dst_lkfile, true)
                end
            end
    
            copy_lkfile()
            fs.copy_file(tf, dst_assetpath, true)
            print("copy file:", tf:string(), dst_assetpath:string())
        end
    
        mark_texfile[local_assetpath:string()] = dst_assetpath:string():sub(#res_binary_path:string()+2)
    end
end

local function modify_texture_files()
    local ant_textures = fs_util.list_files(viking_assetpath, ".texture", {})

    local pkg_prefix = "/pkg/unity_viking/"
    local dst_pkgprefix = "/pkg/ant.resources.binary/"
    for _, at in ipairs(ant_textures) do
        local atcontent = fs_util.raw_table(at)
        if atcontent.path:match(pkg_prefix) then
            print("modify .texture file:", at:string())
            local assetname = atcontent.path:sub(#pkg_prefix+1)
            local dst_assetname = fs.path(assert(mark_texfile[assetname]))
            local newpkg_assetname = dst_pkgprefix .. dst_assetname:string()
    
            atcontent.path = newpkg_assetname
    
            write_table_content(atcontent, at)
        end
    end
end

copy_files()
wait_jobs()

modify_texture_files()
