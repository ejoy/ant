local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local fs = require "filesystem"
local lfs = require "filesystem.local"

local srcfile = arg[1]
local srcpath = fs.path(srcfile)

local function stringify(t)
    local s = {}
    for k, v in pairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
end

cr.set_setting("material", stringify {
    os = "windows",
    renderer = "direct3d11",
    hd = nil,
    obl = nil,
})

local output = lfs.path "./tools/material_compile/output"

if srcpath:equal_extension "material" then
    cr.compile_file(srcpath:localpath())
else
    local stage = srcpath:filename():string():match "([vfc]s)_%w+"

    local mc = {
        fx = {
            [stage] = srcpath,
        }
    }
    
    local tmpfile = lfs.path "./tools/material_compile/tmp.material"

    local f = lfs.open(tmpfile, "wb")
    f:write(serialize.stringify(mc))
    f:close()

    cr.do_compile(tmpfile, output)
    lfs.remove(tmpfile)
end

