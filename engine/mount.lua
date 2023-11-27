local mount = {}

local lfs = require "bee.filesystem"
local datalist = require "datalist"

local MountConfig <const> = [[
mount:
    /engine/ %engine%/engine
    /pkg/    %engine%/pkg
    /        %project%
    /        %project%/mod
]]

local function loadmount(repo)
	local f <close> = io.open((repo._root / ".mount"):string(), "rb")
	if f then
		local cfg = datalist.parse(f:read "a")
		if cfg then
			return cfg
		end
	end
	return datalist.parse(MountConfig)
end

function mount.add(repo, vpath, lpath)
	if not lfs.exists(lpath) then
		return
	end
	assert(vpath:sub(1,1) == "/")
	for _, value in ipairs(repo._mountlpath) do
		if value:string() == lpath then
			return
		end
	end
	repo._mountvpath[#repo._mountvpath+1] = vpath
	repo._mountlpath[#repo._mountlpath+1] = lfs.absolute(lpath):lexically_normal()
end

function mount.read(repo)
	local cfg = loadmount(repo)
	repo._mountvpath = {}
	repo._mountlpath = {}
	for i = 1, #cfg.mount, 2 do
		local vpath, lpath = cfg.mount[i], cfg.mount[i+1]
		mount.add(repo, vpath, lpath:gsub("%%([^%%]*)%%", {
			engine = lfs.current_path():string(),
			project = repo._root:string():gsub("(.-)[/\\]?$", "%1"),
		}))
	end
end

return mount
