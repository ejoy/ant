dofile "libs/editor.lua"
local localfs = require "filesystem.local"
local pm = require "antpm"
local PKGDIR = localfs.current_path() / localfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
pm.import(pm.register(PKGDIR))
