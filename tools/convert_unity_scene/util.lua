local util = {}; util.__index = util

function util.loadworld(scenefile)
	local c, err = loadfile(scenefile:string())
	if c == nil then
		error(string.format("load file error:", err))
	end
	return c()
end

return util