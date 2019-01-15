dofile "libs/editor.lua"

local fs = require "filesystem"
local vfs = require "vfs"

local PKGDIR = fs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
local pkgname = PKGDIR:filename()

local absPKGDIR = fs.current_path() / PKGDIR
vfs.add_mount(pkgname:string(), absPKGDIR)
vfs.add_mount("entry", absPKGDIR)

local pm = require "antpm"
pm.import(pm.register(fs.path "entry"))
