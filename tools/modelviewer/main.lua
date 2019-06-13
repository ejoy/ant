dofile "libs/editor.lua"

local lfs = require "filesystem.local"
local absPKGDIR = lfs.current_path() / lfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
local pm = require "antpm"
pm.import(pm.register(absPKGDIR))
