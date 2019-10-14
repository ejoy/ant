local lfs = require "filesystem.local"
local g_log = log
local converter = {
	fx		= require "fx.compile",
	mesh 	= require "mesh.convert",
	texture = require "texture.convert",
}

local logfolder = lfs.current_path() / "log"
lfs.create_directories(logfolder)

local logfile = nil

local function get_logfile()
	if logfile == nil then
		logfile = assert(lfs.open(logfolder / "fileconvert.log", "a"))
	end

	return logfile
end

local origin = os.time() - os.clock()
local function os_date()
    local ti, tf = math.modf(origin + os.clock())
    return os.date('%Y-%m-%d %H:%M:%S:{ms}', ti):gsub('{ms}', math.floor(tf*1000))
end

local function log_err(src, lk, err)
	local log = get_logfile()
	local errinfo = string.format("[fileconvert:%s]src:%s, lk:%s, error:%s\n", os_date(), src, lk, err)
	log:write(errinfo)
	log:flush()
	print(errinfo)
	if g_log then g_log.error(errinfo) end
end

local function log_info(info)
	local log = get_logfile()
	log:write(string.format("[fileconvert-info:%s]%s\n", os_date(), info))
	log:flush()
end

local function link(plat, srcfile, dstfile)
	local ctype = srcfile:extension():string():lower():sub(2)
	local c = assert(converter[ctype])
	log_info(string.format("plat:%s, src:%s, dst:%s, cvt type:%s", plat, srcfile, dstfile, ctype))
	local success, err, deps = c(plat, srcfile, dstfile)
	if not success and err then
		log_err(srcfile, err)
		return
	end
	if deps then
		table.insert(deps, 1, srcfile)
		return deps
	end
	return {
		srcfile,
	}
end

local function prelink(srcfile)
	local ext = srcfile:extension():string():lower()
	if ext ~= ".fx" then
		return {
			srcfile,
		}
	end
end

return {
	prelink = prelink,
	link = link,
	converter = converter,
	default_cfg = {
		mesh = require "mesh.default_cfg"
	}
}
