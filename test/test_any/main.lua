----------------modify package.lua------------------
local entry_name = ...
-- entry_name = "entry_test_hub"
if not entry_name then
    print("entry_name is nil,pass an arg (like entry_test_hierarchy) to run main.lua")
    return
end
local main_path = debug.getinfo(1, 'S').source:sub(2)
local package_path = io.open(string.gsub(main_path,"main.lua","package.lua"),"w")
local package_content = [[return {
    name = "ant.testempty",
    entry = "%s",
}]]
package_path:write(string.format(package_content,entry_name))
package_path:close()
----------------modify package.lua------------------ 

dofile "libs/editor.lua"

local fs = require "filesystem"
local localfs = require "filesystem.local"
local vfs = require "vfs"

local PKGDIR = localfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
local pkgname = PKGDIR:filename()

local absPKGDIR = localfs.current_path() / PKGDIR

vfs.add_mount(pkgname:string(), absPKGDIR)
vfs.add_mount("entry", absPKGDIR)

local paths = vfs.list("/")
-- print("vfs.list")
-- print_r(paths)
-- print("vfs.list end")


local pm = require "antpm"
pm.import(pm.register(fs.path "entry"))
print("pm.register")



