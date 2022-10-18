local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local fs = require "filesystem"
local lfs = require "filesystem.local"

local sc = arg[1]
local scpath = fs.path(sc)
local stage = scpath:filename():string():match "([vfc]s)_%w+"

local mc = {
    fx = {
        [stage] = sc,
    }
}

local tmpfile = lfs.path "./tools/material_compile/tmp.material"
local output = lfs.path "./tools/material_compile/output"

local f = lfs.open(tmpfile, "wb")
f:write(serialize.stringify(mc))
f:close()

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
cr.do_compile(tmpfile, output)
lfs.remove(tmpfile)
