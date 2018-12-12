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

local function get_logfile()
	if logfile == nil then
		if not fu.exist("log") then
			lfs.mkdir("log")
		end

		logfile = localfile.open("log/fileconvert.log", "wb")
	end

	return assert(logfile)
end

local function log_err(src, lk, err)
	local log = get_logfile()

	log:write(string.format("[fileconvert]src:%s, lk:%s, error:%s\n", src, lk, err))
	log:flush()
end

local function log_info(info)
	local log = get_logfile()
	log:write(string.format("[fileconvert-info:%s]", info))
	log:flush()
end

return function (plat, sourcefile, lkfile, dstfile)
	local lkcontent = rawtable(lkfile, fu.read_from_file)

	local ctype = assert(lkcontent.type)
	local converter_name = assert(converter_names[ctype])

	local c = require(converter_name)
	log_info(string.format("plat:%s, src:%s, lk:%s, dst:%s, cvt type:%s", plat, sourcefile, lkfile, dstfile, ctype))
	local success, err = c(plat, sourcefile, lkcontent, dstfile)
	if err then
		log_err(sourcefile, lkfile, err)
	end

	return success
end