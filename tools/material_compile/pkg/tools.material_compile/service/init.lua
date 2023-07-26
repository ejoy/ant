package.path = "/engine/?.lua"
require "bootstrap"


local cr = import_package "ant.compile_resource".fileserver()
local serialize = import_package "ant.serialize"

local access = require "vfs.repoaccess"
require "editor.create_repo" ("./tools/material_compile", access)

local fs = require "filesystem"
local lfs = require "filesystem.local"

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

cr.set_setting("material", stringify {
    os = "windows",
    renderer = "vulkan",
    hd = nil,
    obl = nil,
})

local output = lfs.path "./tools/material_compile/output"

if srcpath:equal_extension "material" then
    cr.compile_file(srcpath:localpath())
elseif srcpath:equal_extension "lua" then
    local files, err = dofile(srcpath:localpath():string())
    if files == nil then
        error(("load %s failed: %s"):format(srcpath:string(), err))
    end
    local function readfile(ff) local f<close> = fs.open(ff); return f:read "a" end
    local RES_EXT = {
        [".prefab"]     = function (filename)
            local r = serialize.parse(filename, readfile(fs.path(filename)))
            for _, e in ipairs(r) do
                local d = e.data
                if d.mesh then
                    cr.compile_file(fs.path(d.mesh):localpath())
                end

                if d.material then
                    cr.compile_file(fs.path(d.material):localpath())
                end
            end
        end,
        [".material"]   = function (filename)
            cr.compile_file(fs.path(filename):localpath())
        end,
        [".glb"]        = function (filename)
            cr.compile_file(fs.path(filename):localpath())
        end,
    }
    
    for _, f in ipairs(files) do
        local ext = fs.path(f):extension():string():lower()
        local op = RES_EXT[ext]
        if op then
            op(f)
        end
    end
else
    local stage = srcpath:filename():string():match "([vfc]s)_%w+"

    local mc = {
        fx = {
            [stage] = srcfile,
        }
    }
    
    local tmpfile = lfs.path "./tools/material_compile/tmp.material"

    local f = lfs.open(tmpfile, "wb")
    f:write(serialize.stringify(mc))
    f:close()

    cr.do_compile(tmpfile, output)
    lfs.remove(tmpfile)
end

