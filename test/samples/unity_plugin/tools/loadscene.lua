
local scene = {}
scene.__index = scene 

local readfile = function( fname )
	local f = assert(io.open( fname,'rb'))
	local d = f:read('*a')
	f:close()
	return d 
end

local writefile = function( fname, content)
	local f = assert(io.open( fname,"w"))
	f:write(context)
	f:cloase() 
	return d
end 

function scene:loadUnityJson(path)
	-- todo:
end 
function scene:loadUnityBinary(path)
	-- todo:
end 

function scene:loadUnityLua(path)
	local source = readfile(path)
	local world  = load(source)()
	return world 
end 

function scene:loadUnityScene(path)
	return self:loadUnityLua(path);
end 


return scene 
