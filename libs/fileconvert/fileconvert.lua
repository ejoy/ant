local rawtable = require "common.rawtable"
local fs = require "filesystem"
local fsutil = require "filesystem.fsutil"

local converter_names = {
	shader = "fileconvert.compileshadersource",
	mesh = "fileconvert.convertmesh",
	texture = "",
}

if not fs.exists("log") then
	lfs.mkdir("log")
end

local function get_logfile()
	return assert(fsutil.open("log/fileconvert.log", "a"))
end

local origin = os.time() - os.clock()
local function os_date()
    local ti, tf = math.modf(origin + os.clock())
    return os.date('%Y-%m-%d %H:%M:%S:{ms}', ti):gsub('{ms}', math.floor(tf*1000))
end

local function log_err(src, lk, err)
	local log = get_logfile()

	log:write(string.format("[fileconvert:%s]src:%s, lk:%s, error:%s\n", os_date(), src, lk, err))
	log:close()
end

local function log_info(info)
	local log = get_logfile()
	log:write(string.format("[fileconvert-info:%s]%s\n", os_date(), info))
	log:close()
end

return function (plat, sourcefile, lkfile, dstfile)
	local lkcontent = rawtable(lkfile, 	function (filename, mode)
		mode = mode or "rb"
		local f = fs.open(filename, mode)
		local c = f:read("a")
		f:close()
		return c
	end)

	local ctype = assert(lkcontent.type)
	local converter_name = assert(converter_names[ctype])

	local c = require(converter_name)
	log_info(string.format("plat:%s, src:%s, lk:%s, dst:%s, cvt type:%s", plat, sourcefile, lkfile, dstfile, ctype))
	local success, err = c(plat, sourcefile, lkcontent, dstfile)
	if not success and err then		
		print("source file:", sourcefile, "lk file:", lkfile, "error:", err)		
		log_err(sourcefile, lkfile, err)
	end

	return success
end