local rawtable = require "common.rawtable"
local localfile = require "filesystem.file"
local fu = require "filesystem.util"
local lfs = require "lfs"

local converter_names = {
	shader = "fileconvert.compileshadersource",
	mesh = "fileconvert.convertmesh",
	texture = "",
}

local logfile = nil

local function log_err(src, lk, err)
	if logfile == nil then
		if not fu.exist("log") then
			lfs.mkdir("log")
		end

		logfile = localfile.open("log/fileconvert.log")
	end

	logfile:write(string.format("[fileconvert]src:%s, lk:%s, error:\n", src, lk, err))
	logfile:flush()
end

return function (plat, sourcefile, lkfile, dstfile)
	local lkcontent = rawtable(lkfile, fu.read_from_file)

	local ctype = assert(lkcontent.type)
	local converter_name = assert(converter_names[ctype])

	local c = require(converter_name)
	local success, err = c(plat, sourcefile, lkcontent, dstfile)
	if err then
		log_err(sourcefile, lkfile, err)
	end

	return success
end