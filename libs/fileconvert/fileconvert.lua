local rawtable = require "common.rawtable"

local converter_names = {
	shader = "fileconvert.compileshadersource",
	mesh = "fileconvert.convertmesh",
	texture = "",
}

local function readlocal_file(filename)
	local nativeopen = require "filesystem.file" 
	local f, err = nativeopen.open(filename, "rb")
	if f == nil then
		error(err)
	end
	local data = f:read "a"
	f:close()
	return data
end

return function (plat, sourcefile, lkfile, dstfile)
	local lkcontent = rawtable(lkfile, readlocal_file)

	local ctype = assert(lkcontent.type)
	local converter_name = assert(converter_names[ctype])

	local c = require(converter_name)
	return c(plat, sourcefile, lkcontent, dstfile)
end