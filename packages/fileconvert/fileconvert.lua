local lfs = require "filesystem.local"
local converter = {
	fx		= require "fx.compile",
	mesh 	= require "mesh.convert",
	texture = require "texture.convert",
}

local log = require "common.log".fork()
lfs.create_directories(lfs.current_path() / "log")
log.file = assert(lfs.open(lfs.current_path() / "log" / "fileconvert.log", "a"))
function log.raw(data)
	log.file:write(data)
	log.file:write("\n")
	log.file:flush()
end

local function link(plat, linkconfig, srcfile, dstfile, localpath)
	local ext = srcfile:extension():string():lower()
	local c = assert(converter[ext:sub(2)])
	log.info(string.format("plat:%s, src:%s, dst:%s, cvt type:%s", plat, srcfile, dstfile, ext))
	local success, err, deps = c(plat, srcfile, dstfile, localpath)
	if not success and err then
		log.error(string.format("src:%s, error:%s", srcfile, err))
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

local function depend(srcfile)
	local ext = srcfile:extension():string():lower()
	if ext ~= ".fx" then
		return {
			srcfile,
		}
	end
end

return {
	depend = depend,
	link = link,
	converter = converter,
	shader_toolset = require "fx.toolset",
	default_cfg = {
		mesh = require "mesh.default_cfg"
	}
}
