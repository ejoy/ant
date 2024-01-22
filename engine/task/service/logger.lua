local ltask = require "ltask"
local platform = require "bee.platform"

local S = {}
local lables = {}
local command = {}
local tasks = {}

local function querylabel(id)
	if not id then
		return "unknown"
	end
	if id == 0 then
		return "system"
	end
	if lables[id] then
		return lables[id]
	end
	return "unknown"
end

local function service(id)
	return ("(%s:%d)"):format(querylabel(id), id)
end

function command.startup(id, label)
	lables[id] = label
	return service(id) .. " startup."
end

function command.quit(id)
	tasks[#tasks+1] = function ()
		lables[id] = nil
	end
	return service(id) .. " quit."
end

function command.service(_, id)
	id = tonumber(id)
	return service(id)
end

local function parse(id, s)
	local name, args = s:match "^([^:]*):(.*)$"
	if not name then
		name = s
		args = nil
	end
	local f = command[name]
	if f then
		return f(id, args)
	end
	return s
end

local LOG_ERROR = (function ()
	if platform.os == 'ios' then
		return function (data)
			io.write(data)
			io.write("\n")
			io.flush()
		end
	elseif platform.os == 'android' then
		local android = require "android"
		return function (data)
			android.rawlog("error", "", data)
		end
	end
	return function (_)
	end
end)()

local LOG = (function ()
	if __ANT_RUNTIME__ then
		local ServiceIO = ltask.queryservice "io"
		local directory = require "directory"
		local fs = require "bee.filesystem"
		local logpath = directory.app_path():string()
		local logfile = logpath .. "/game.log"
		fs.create_directories(logpath)
		if fs.exists(logfile) then
			fs.rename(logfile, logpath .. "/game_1.log")
		end
		return function (level, data)
			ltask.send(ServiceIO, "SEND", "LOG", data)
			local f <close> = io.open(logfile, "a+")
			if f then
				f:write(data)
				f:write("\n")
			end
			if level == "error" then
				LOG_ERROR(data)
			end
		end
	elseif platform.os == 'windows' then
		local windows = require "bee.windows"
		if windows.isatty(io.stdout) then
			return function (_, data)
				windows.write_console(io.stdout, data)
				windows.write_console(io.stdout, "\n")
			end
		end
	end
	return function (_, data)
		io.write(data)
		io.write("\n")
		io.flush()
	end
end)()

local function writelog()
	while true do
		local ti, id, msg, sz = ltask.poplog()
		if ti == nil then
			break
		end
		local tsec = ti // 100
		local msec = ti % 100
		local level, message = ltask.unpack_remove(msg, sz)
		message = string.gsub(message, "%$%{([^}]*)%}", function (s)
			return parse(id, s)
		end)
		LOG(level, string.format("[%s.%02d][%-5s]( %s )%s", os.date("%Y-%m-%d %H:%M:%S", tsec), msec, level:upper(), querylabel(id), message))
	end
end

ltask.fork(function ()
	while true do
		writelog()
		ltask.sleep(100)
	end
end)

function S.quit()
	writelog()
end

function S.labels()
	return lables
end

return S
