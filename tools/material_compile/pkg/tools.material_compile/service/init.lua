local platform  = require "bee.platform"

local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local access = dofile "/engine/editor/vfs_access.lua"
dofile "/engine/editor/create_repo.lua" ("./tools/material_compile", access)

local fs = require "filesystem"
local lfs = require "bee.filesystem"
local fastio = require "fastio"

local arg = select(1, ...)
local srcfile = arg[1]
local srcpath = fs.path(srcfile)

local RENDERERS<const> = {
    macos   = "metal",
    windows = "direct3d11",
}

local renderer<const> = RENDERERS[platform.os] or error (("not support os for compile shader:%s"):format(platform.os))

local cfg = cr.init_setting(require "vfs", ("%s-%s"):format(platform.os, renderer))

local output = lfs.path "./tools/material_compile/output"

local ltask = require "ltask"

if srcpath:equal_extension "material" then
    cr.compile_file(cfg, srcpath:string(), srcpath:localpath():string())
elseif srcpath:equal_extension "lua" then
    local files, err = dofile(srcpath:localpath():string())
    if files == nil then
        error(("load %s failed: %s"):format(srcpath:string(), err))
    end
    local compile_files = {}
    local mark_files = {}
    local function add_compile_file(f)
        local pos = f:find("|", 1, true)
        if pos then
            f = f:sub(1, pos-1)
        end

        if nil == mark_files[f] then
            mark_files[f] = true
            compile_files[#compile_files+1] = {
                function ()
                    local r, eee = pcall(cr.compile_file, cfg, f, fs.path(f):localpath())
                    if not r then
                        print("compile error:", f, "error:", eee)
                    end
                end
            }
        end
    end
    local RES_EXT = {
        [".prefab"]     = function (filename)
            if filename:match "%|animation.prefab" then
                print("not load animation.prefab file:", filename)
                return
            end
            local r = serialize.parse(filename, fastio.readall_f(filename))
            for _, e in ipairs(r) do
                local d = e.data
                if d.mesh then
                    add_compile_file(d.mesh)
                end

                if d.material then
                    add_compile_file(d.material)
                end
            end
        end,
        [".material"]   = add_compile_file,
        [".glb"]        = add_compile_file,
    }

    for _, f in ipairs(files) do
        local ext = fs.path(f):extension():string():lower()
        local op = RES_EXT[ext]
        if op then
            op(f)
        end
    end

    for _ in ltask.parallel(compile_files) do
    end

    print("compiled finished, totals compiled:", #compile_files)
elseif srcpath:equal_extension "glb" then
    -- local f = srcpath:string()
    -- local pos = f:find("|", 1, true)
    -- if pos then
    --     f = f:sub(1, pos-1)
    -- end
    cr.compile_file(cfg, srcpath:string(), srcpath:localpath():string())
else
    local stage = srcpath:filename():string():match "([vfc]s)_%w+"

    local mc = {
        fx = {
            [stage] = srcfile,
        }
    }

    local tmpfile = lfs.path "./tools/material_compile/tmp.material"

    local f = assert(io.open(tmpfile:string(), "wb"))
    f:write(serialize.stringify(mc))
    f:close()

    cr.do_compile(tmpfile, output)
    lfs.remove(tmpfile)
end

