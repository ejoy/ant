dofile "libs/editor.lua"

local fs = require "filesystem"
local PKGDIR = fs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
local pm = require "antpm"
pm.import(pm.register(PKGDIR))
