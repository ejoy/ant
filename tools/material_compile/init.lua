local cr = import_package "ant.compile_resource"
local stringify = import_package "ant.serialize".stringify

local lfs = require "filesystem.local"

local sc = arg[1]
local scpath = lfs.path(sc)
local stage = scpath:filename():string():match "([vf]s)_%w+"

local mc = {
    fx = {
        [stage] = sc,
    }
}

local tmpfile = lfs.path "tmp.material"

local f<close> = lfs.open(tmpfile, "wb")
f:write(stringify(mc))
cr.init()
cr.compile_file(tmpfile)