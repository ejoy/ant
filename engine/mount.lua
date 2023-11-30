local mount = {}

local fs = require "bee.filesystem"
local datalist = require "datalist"
local fastio = require "fastio"

local MountConfig <const> = [[
mount:
    /engine/ %engine%/engine
    /pkg/    %engine%/pkg
    /        %project%
    /        %project%/mod
]]

local function loadmount(rootpath)
	local path = rootpath / ".mount"
	if fs.exists(path) then
		local cfg = datalist.parse(fastio.readall_f(path:string()))
		if cfg then
			return cfg
		end
	end
	return datalist.parse(MountConfig)
end

function mount.add(repo, vpath, lpath)
	if not fs.exists(lpath) then
		return
	end
	assert(vpath:sub(1,1) == "/")
	for _, value in ipairs(repo._mountlpath) do
		if value:string() == lpath then
			return
		end
	end
	repo._mountvpath[#repo._mountvpath+1] = vpath
	repo._mountlpath[#repo._mountlpath+1] = fs.absolute(lpath):lexically_normal()
end

function mount.read(repo)
	repo._mountvpath = {}
	repo._mountlpath = {}
	do
		local rootpath = repo._root
		local cfg = loadmount(rootpath)
		for i = 1, #cfg.mount, 2 do
			local vpath, lpath = cfg.mount[i], cfg.mount[i+1]
			mount.add(repo, vpath, lpath:gsub("%%([^%%]*)%%", {
				engine = fs.current_path():string(),
				project = rootpath:string():gsub("(.-)[/\\]?$", "%1"),
			}))
		end
	end
	if __ANT_EDITOR__ then
		local rootpath = fs.path(__ANT_EDITOR__)
		local cfg = loadmount(rootpath)
		for i = 1, #cfg.mount, 2 do
			local vpath, lpath = cfg.mount[i], cfg.mount[i+1]
			if not lpath:match "%%engine%%" then
				mount.add(repo, vpath, lpath:gsub("%%([^%%]*)%%", {
					project = rootpath:string():gsub("(.-)[/\\]?$", "%1"),
				}))
			end
		end
	end
end

return mount
