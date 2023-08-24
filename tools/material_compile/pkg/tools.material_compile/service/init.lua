local platform  = require "bee.platform"

local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local access = dofile "/engine/vfs/repoaccess.lua"
dofile "/engine/editor/create_repo.lua" ("./tools/material_compile", access)

local fs = require "filesystem"
local lfs = require "bee.filesystem"

local arg = select(1, ...)
local srcfile = arg[1]
local srcpath = fs.path(srcfile)

cr.init_setting()

local function stringify(t)
    local s = {}
    for k, v in pairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
end

local texture_extensions <const> = {
    noop        = platform.os == "windows" and "dds" or "ktx",
	direct3d11 	= "dds",
	direct3d12 	= "dds",
	metal 		= "ktx",
	vulkan 		= "ktx",
	opengl 		= "ktx",
}

local BgfxOS <const> = {
    macos = "osx",
}

local RENDERERS<const> = {
    macos   = "metal",
    windows = "direct3d11",
}

local renderer<const> = assert(RENDERERS[platform.os], ("not support os for compile shader:%s"):format(platform.os))

cr.set_setting("material", stringify {
    os = BgfxOS[platform.os] or platform.os,
    renderer = renderer,
    hd = nil,
    obl = nil,
})

cr.set_setting("glb", stringify {
})

local texture = assert(texture_extensions[renderer])

cr.set_setting("texture", stringify {os=platform.os, ext=texture})

local output = lfs.path "./tools/material_compile/output"

local ltask = require "ltask"

if srcpath:equal_extension "material" then
    cr.compile_file(srcpath:localpath():string())
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
                    local r, eee = pcall(cr.compile_file, fs.path(f):localpath())
                    if not r then
                        print("compile error:", f, "error:", eee)
                    end
                end
            }
        end
    end
    local function readfile(ff) local f<close> = fs.open(ff); return f:read "a" end
    local RES_EXT = {
        [".prefab"]     = function (filename)
            if filename:match "%|animation.prefab" then
                print("not load animation.prefab file:", filename)
                return 
            end
            local r = serialize.parse(filename, readfile(fs.path(filename)))
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

