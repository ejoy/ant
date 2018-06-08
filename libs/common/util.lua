local util = {}; util.__index = util

function util.deep_copy(t)
	local tmp = {}
	for k, v in pairs(t) do
		tmp[k] = type(v) == "table" and util.deep_copy(v) or v		
	end
	return tmp
end

return util