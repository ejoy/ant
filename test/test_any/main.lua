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
local localfs = require "filesystem.local"
local pm = require "antpm"
local PKGDIR = localfs.current_path() / localfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
pm.import(pm.register(PKGDIR))
