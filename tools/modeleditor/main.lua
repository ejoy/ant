dofile "libs/editor.lua"

local localfs = require "filesystem.local"
local vfs = require "vfs"

local PKGDIR = localfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
local pkgname = PKGDIR:filename()

local absPKGDIR = localfs.current_path() / PKGDIR
vfs.add_mount(pkgname:string(), absPKGDIR)
vfs.add_mount("entry", absPKGDIR)

local pm = require "antpm"
pm.import(pm.register("entry"))
