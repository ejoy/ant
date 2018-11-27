dofile "libs/init.lua"

local reponame = assert(...,  "Need repo name")
local config = {
	address = "0.0.0.0",
	port = 2018,
}

local function LOG(...)
	print(...)
end

local ok, fw = pcall(require, "filewatch")
if not ok then fw = nil end

local vrepo = require "vfs.repo"
local fs = require "lfs"
local network = require "network"
local protocol = require "protocol"
local fileconvert = require "fileconvert"
local util = require "filesystem.util"

local home = util.personaldir()
local repopath = home .. "/" .. reponame

LOG ("Open repo : ", repopath)
local function convertfiles(dirs)
	for _, d in ipairs (dirs) do
		fileconvert.convert_dir(d)
	end
end

local repo = assert(vrepo.new(repopath))

LOG ("Compile repo")
convertfiles {repopath .. "/assets", repo:realpath("engine/assets")} -- need call before repo build

LOG ("Rebuild repo")
local roothash = repo:index()
repo:rebuild()

local wid = {}
if fw then
	local id = assert(fw.add(repopath, 'fdts'))
	wid[id] = ''
	for k, v in pairs(repo._mountpoint) do
		local id = assert(fw.add(v, 'fdts'))
		wid[id] = k
	end
end

local filelisten = network.listen(config.address, config.port)
LOG ("Listen :", config.address, config.port, filelisten)

local function response(obj, ...)
	network.send(obj, protocol.packmessage({...}))
end

local debug = {}
local message = {}

function message:ROOT()
	fileconvert.convert_watchfiles()
	repo:build()
	local roothash = repo:root()
	response(self, "ROOT", roothash)
end

function message:GET(hash)
	local filename = repo:hash(hash)
	if filename == nil then
		response(self, "MISSING", hash)
		return
	end
	local f = io.open(filename, "rb")
	if not f then
		response(self, "MISSING", hash)
		return
	end
	local sz = f:seek "end"
	f:seek("set", 0)
	if sz < 0x10000 then
		response(self, "BLOB", hash, f:read "a")
	else
		response(self, "FILE", hash, tostring(sz))
		local offset = 0
		while true do
			local data = f:read(0x8000)
			response(self, "SLICE", hash, tostring(offset), data)
			offset = offset + #data
			if offset >= sz then
				break
			end
		end
	end
	f:close()
end

function message:LINK(hash, plat, source_hash, lk_hash)
	local binhash = repo:link(hash, plat, source_hash, lk_hash)
	if binhash then
		response(self, "LINK", hash, binhash)
	else
		response(self, "LINK")
	end
end

function message:DBG(data)
	if data == "" then
		local fd = network.listen('127.0.0.1', 4278)
		debug[fd] = { server = self }
		return
	end
	for _, v in pairs(debug) do
		if v.server == self then
			if v.client then
				network.send(v.client, data)
			end
			break
		end
	end
end

local output = {}
local function dispatch_obj(obj)
	local reading_queue = obj._read
	while true do
		local msg = protocol.readmessage(reading_queue, output)
		if msg == nil then
			break
		end
		LOG("REQ :", obj._peer, msg[1])
		local f = message[msg[1]]
		if f then
			f(obj, table.unpack(msg, 2))
		end
	end
end

local function is_fileserver(obj)
	return filelisten == obj._ref
end

local function fileserver_update(obj)
	dispatch_obj(obj)
	if obj._status == "CONNECTING" then
		LOG("New", obj._peer, obj._ref)
	elseif obj._status == "CLOSED" then
		LOG("LOGOFF", obj._peer)
		for fd, v in pairs(debug) do
			if v.server == obj then
				network.close(fd)
			end
		end
	end
end

local function is_dbgserver(obj)
	return debug[obj._ref] ~= nil
end

local function dbgserver_update(obj)
	local dbg = debug[obj._ref]
	local data = table.concat(obj._read)
	obj._read = {}
	if data ~= "" then
		response(dbg.server, "DBG", data)
	end
	if obj._status == "CONNECTING" then
		LOG("New", obj._peer, obj._ref)
		if dbg.client then
			network.close(obj)
		else
			dbg.client = obj
		end
	elseif obj._status == "CLOSED" then
		LOG("LOGOFF", obj._peer)
		local dbg = debug[obj._ref]
		if dbg.client == obj then
			dbg.client = nil
		end
		response(dbg.server, "DBG", "") --close DBG
	end
end

local function filewacth()
	while true do
		local id, type, path = fw.select()
		if not id then
			break
		end
		if wid[id] == '' and path:sub(1, 5) == '.repo' then
			goto continue
		end
		local dir = wid[id]
		local path = (dir == '') and path or (dir .. '/' .. path)
		path = path:gsub('\\', '/')
		LOG('[FileWatch]', type, path)
		fileconvert.watch_file(repo:realpath(path))
		repo:touch(path)
		::continue::
	end
end

local function mainloop()
	local objs = {}
	if network.dispatch(objs, 0.1) then
		for k,obj in ipairs(objs) do
			objs[k] = nil
			if is_fileserver(obj) then
				fileserver_update(obj)
			elseif is_dbgserver(obj) then
				dbgserver_update(obj)
			end
		end
	end
	if fw then
		filewacth()
	end
end

while true do
	mainloop()
end
