dofile "libs/init.lua"

local reponame = assert(...,  "Need repo name")
local config = {
	address = "0.0.0.0",
	port = 2018,
}

local function LOG(...)
	print(...)
end

local fw = require "filewatch"
local vrepo = require "vfs.repo"
local network = require "network"
local protocol = require "protocol"
local fs = require "lfs"
local util = require "filesystem.util"
local fspath = require "filesystem.path"

local home = util.personaldir()
local repopath = home .. "/" .. reponame

assert(loadfile "tools/repo/newrepo.lua")(reponame)

LOG ("Open repo : ", repopath)

local repo = assert(vrepo.new(repopath))

LOG ("Rebuild repo")
repo:index()
repo:rebuild()

local watch = {}
assert(fw.add(repopath))
watch[#watch+1] = {'', repopath}
for k, v in pairs(repo._mountpoint) do
	assert(fw.add(v))
	watch[#watch+1] = {k, v}
end

local filelisten = network.listen(config.address, config.port)
LOG ("Listen :", config.address, config.port, filelisten)

local function response(obj, ...)
	network.send(obj, protocol.packmessage({...}))
end

local rtlog = {}

function rtlog.init()
	fs.mkdir('./log/runtime/')
	os.rename('./log/runtime.log', ('./log/runtime/%s.log'):format(os.date('%Y_%m_%d_%H_%M_%S')))
end

function rtlog.write(data)
	local fp = assert(io.open('./log/runtime.log', 'a'))
	fp:write(data)
	fp:write('\n')
	fp:close()
end


local debug = {}
local message = {}

function message:ROOT()
	repo:build()
	local roothash = repo:root()
	response(self, "ROOT", roothash)
	rtlog.init()
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

function message:LINK(hash, identity, source_hash, lk_hash)
	local binhash = repo:link(hash, identity, source_hash, lk_hash)
	LOG("LINK", hash, binhash, identity, source_hash, lk_hash)
	if binhash then
		response(self, "LINK", hash, binhash)
	else
		response(self, "LINK", hash)
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

function message:LOG(data)
	rtlog.write(data)
end

local output = {}
local function dispatch_obj(obj)
	local reading_queue = obj._read
	while true do
		local msg = protocol.readmessage(reading_queue, output)
		if msg == nil then
			break
		end
		--LOG("REQ :", obj._peer, msg[1])
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
		--LOG("New", obj._peer, obj._ref)
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
		if dbg.client == obj then
			dbg.client = nil
		end
		response(dbg.server, "DBG", "") --close DBG
	end
end

local function filewatch()
	while true do
		local type, path = fw.select()
		if not type then
			break
		end
		if type == 'error' then
			print(path)
			goto continue
		end
		for _, v in ipairs(watch) do
			local vpath, rpath = v[1], v[2]
			local newpath, ok = fspath.replace_path(path, rpath:gsub('\\', '/'), vpath)
			if ok then
				if newpath:sub(1, 1) == '/' then newpath = newpath:sub(2) end
				if newpath:sub(1, 5) ~= '.repo' then
					print('[FileWatch]', type, newpath)
					repo:touch(newpath)
				end
			end
		end
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
	filewatch()
end

while true do
	mainloop()
end
