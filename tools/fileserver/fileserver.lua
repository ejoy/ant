package.cpath = table.concat({
	"clibs/?.dll",
	"bin/?.dll",
}, ";")
require "editor.vfs"

local default_reponame = arg[1]
local config = {
	address = "0.0.0.0",
	port = 2018,
}

local function LOG(...)
	print(...)
end

local fw = require "filewatch"
local repo_new = require "vfs.repo".new
local protocol = require "protocol"
local network = require "network"
local vfs = require "vfs.simplefs"
local lfs = require "filesystem.local"

local WORKDIR = lfs.current_path()

local watch = {}
local repos = {}
local clients = {1}

local function watch_add_path(path, repo, url)
	path = path:string()
	if watch[path] then
		local info = watch[path].info
		info[#info+1] = {
			repo = repo,
			url = url,
		}
	else
		watch[path] = {
			id = assert(fw.add(path)),
			info = {{
				repo = repo,
				url = url,
			}}
		}
	end
end

local function watch_add(repo, repopath)
	watch_add_path(repopath, repo, '')
	for k, v in pairs(repo._mountpoint) do
		watch_add_path(v, repo, k)
	end
end

local function watch_remove(repo)
	local del = {}
	for path, w in pairs(watch) do
		for i, v in ipairs(w.info) do
			if v.repo == repo then
				table.remove(w.info, i)
				break
			end
		end
		if #w.info == 0 then
			fw.remove(w.id)
			del[path] = true
		end
	end
	for _, path in pairs(del) do
		watch[path] = nil
	end
end

local function repo_add(reponame)
	if repos[reponame] then
		return repos[reponame]
	end
	local repopath = lfs.path(reponame)
	LOG ("Open repo : ", repopath)
	local repo = assert(repo_new(repopath))
	LOG ("Rebuild repo")
	if lfs.is_regular_file(repopath / ".repo" / "root") then
		repo:index()
	else
		repo:rebuild()
	end
	watch_add(repo, repopath)
	repos[reponame] = repo
	return repo
end

local function repo_remove(reponame)
	local repo = repos[reponame]
	if repo then
		watch_remove(repo)
	end
end

local function clients_add()
	local ret = clients[1]
	if #clients == 1 then
		clients[1] = ret + 1
	else
		table.remove(clients, 1)
	end
	return ret
end

local function clients_remove(id)
	clients[#clients+1] = id
	table.sort(clients)
end


local function logger_finish(id)
	local logfile = WORKDIR / 'log' / ('runtime-%d.log'):format(id)
	if lfs.exists(logfile) then
		lfs.rename(logfile, WORKDIR / 'log' / 'runtime' / ('%s.log'):format(os.date('%Y_%m_%d_%H_%M_%S')))
	end
end

local function logger_init(id)
	lfs.create_directories(WORKDIR / 'log' / 'runtime')
	logger_finish(id)
end

local filelisten = network.listen(config.address, config.port)
LOG ("Listen :", config.address, config.port, filelisten)

local function response(obj, ...)
	network.send(obj, protocol.packmessage({...}))
end

local debug = {}
local message = {}

function message:ROOT(reponame)
	local reponame = assert(reponame or default_reponame,  "Need repo name")
	local repo = repo_add(reponame)
	self._repo = repo

	if not self._id then
		self._id = clients_add()
	end

	repo:build()
	local roothash = repo:root()
	response(self, "ROOT", roothash)

	logger_init(self._id)
end

function message:GET(hash)
	local repo = self._repo
	local filename = repo:hash(hash)
	if filename == nil then
		response(self, "MISSING", hash)
		return
	end
	local f = io.open(filename:string(), "rb")
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
	local repo = self._repo
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
		LOG("LISTEN DEBUG", '127.0.0.1', 4278)
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
	local logfile = WORKDIR / 'log' / ('runtime-%d.log'):format(self._id)
	local fp = assert(lfs.open(logfile, 'a'))
	fp:write(data)
	fp:write('\n')
	fp:close()
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
		clients_remove(obj._id)
		logger_finish(obj._id)
		obj._id = nil
		for fd, v in pairs(debug) do
			if v.server == obj then
				if v.client then
					network.close(v.client)
				end
				network.close(fd)
				debug[fd] = nil
				break
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
		obj._status = "CONNECTED"
		LOG("New DBG", obj._peer, obj._ref)
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
		for rpath, w in pairs(watch) do
			local rel_path = lfs.relative(lfs.path(path), lfs.path(rpath)):string()
			if rel_path ~= '' and rel_path:sub(1, 1) ~= '.' then
				for _, v in ipairs(w.info) do
					local newpath = vfs.join(v.url, rel_path)
					if newpath:sub(1, 5) ~= '.repo' then
						print('[FileWatch]', type, newpath)
						v.repo:touch(newpath)
					end
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
