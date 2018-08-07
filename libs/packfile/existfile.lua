local require = import and import(...) or require

local winfile =  require "winfile"

local rawexist = winfile.exist

return function (filename)
	local lnk = filename .. ".lnk"
	if rawexist(lnk) then
		return true
	end

	return rawexist(filename)
end