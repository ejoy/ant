----------------modify package.lua------------------
local function get_entry_name()	
	if #arg > 0 then
		for _, a in ipairs(arg) do
			local en = a:match("-e=(.+)")
			if en == nil then
				en = a:match("--entryname=(.+)")
			end
			if en then
				return en
			end
		end
	end
end

local entry_name = get_entry_name()
if entry_name then
    local main_path = debug.getinfo(1, 'S').source:sub(2)
    local package_path = io.open(string.gsub(main_path,"main.lua","package.lua"),"w")
    local package_content = [[return {
        name = "ant.testimgui",
        entry = "%s",
    }]]
    package_path:write(string.format(package_content,entry_name))
    package_path:close()
end
----------------modify package.lua------------------ 

dofile "libs/editor.lua"
local localfs = require "filesystem.local"
local pm = require "antpm"
local PKGDIR = localfs.current_path() / localfs.path(debug.getinfo(1, 'S').source:sub(2)):parent_path()
pm.import(pm.register(PKGDIR))
