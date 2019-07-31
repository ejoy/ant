local lfs = require "filesystem.local"
local util = require "util"
local crypt = require "crypt"
local sha1_encoder = crypt.sha1_encoder()

local converter_names = {
	shader = "shader.compile",
	mesh = "mesh.convert",
	texture = "texture.convert",
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
end

local function log_info(info)
	local log = get_logfile()
	log:write(string.format("[fileconvert-info:%s]%s\n", os_date(), info))
	log:flush()
end

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

local function sha1_from_file(filename)
	sha1_encoder:init()
	local ff = assert(lfs.open(filename, "rb"))
	while true do
		local content = ff:read(1024)
		if content then
			sha1_encoder:update(content)
		else
			break
		end
	end
	ff:close()
	return sha1_encoder:final():gsub(".", byte2hex)
end

return function (plat, reposource, sourcefile, linkfile, dstfile)
	local f = lfs.open(linkfile, "rb")
	if f then
		local cache = f:read "a"
		f:close()
		return cache
	end

	local lkfile = sourcefile .. ".lk"
	local lkcontent = util.rawtable(lkfile)
	local ctype = assert(lkcontent.type)
	local converter_name = assert(converter_names[ctype])

	local c = require(converter_name)
	log_info(string.format("plat:%s, src:%s, lk:%s, dst:%s, cvt type:%s", plat, sourcefile, lkfile, dstfile, ctype))
	local success, err = c(plat, sourcefile, lkcontent, dstfile)
	if not success and err then
		log_err(sourcefile, lkfile, err)
	end

	local binhash = sha1_from_file(dstfile)
	local s = {}
	s[#s+1] = binhash
	s[#s+1] = ("%s %s"):format(sha1_from_file(sourcefile), reposource)
	s[#s+1] = ("%s %s"):format(sha1_from_file(lkfile), reposource .. ".lk")
	local cache = table.concat(s, "\n")
	local lf = lfs.open(linkfile, "wb")
	lf:write(cache)
	lf:close()
	return cache, binhash
end