local _,filename = ...

local rdb = require "remotedebug"
local lsocket = require "lsocket"
local pack = require "debugger.pack"
local aux = require "debugger.debugaux"

local lua_command = {
	"start",
	"lua.exe",
	"-E",
	"-i",
	filename:gsub("[^/\\]+$","client.lua"),
	package.path,
	package.cpath,
}

local function create_pipe()
	local port = 10000
	local socket

	repeat
		socket = assert(lsocket.bind( "127.0.0.1", port))
		if not socket then
			port = port + 1
		end
	until socket

	return socket, port
end

local function do_command(cmd)
	local f, err = load(cmd, "t")
	if not f then
		return "[SYNTAX] : " .. err
	end
	local ret, err = pcall(f)
	if not ret then
		return "[ERROR] : " .. err
	end
	return tostring(ret)
end

local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local debug_cmd = {}

function debug_cmd.frames()
	local frames = aux.frames()
	return table.concat(frames, "\n")
end

function debug_cmd.run(_, cmd)
	return do_command(cmd:sub(4))
end

function debug_cmd.frame(cmdline)
	local f = aux.frame(tonumber(cmdline[2]))
	return tostring(f)
end

local function run(channel)
	while true do
		local cmd = channel:recv()
		if cmd == "quit" then
			break
		end
		local resp
		local cmdline = split_cmdline(cmd)
		local c = cmdline[1]
		local f = debug_cmd[c]
		if f == nil then
			resp = "Unknown command :" .. c
		else
			resp = f(cmdline, cmd)
		end
		channel:send(resp or "")
	end
end

local function launch_console()
	local lfd, port = create_pipe()
	table.insert(lua_command, port)
	local command = table.concat(lua_command, " ")

	os.execute(command)
	if not lsocket.select ({lfd}, 2000) then	-- wait 2 sec
		print "Timeout"
		return
	end
	local fd = assert(lfd:accept())
	lfd:close()

	local channel = pack.new(fd)

	local ok, err = pcall(run, channel)
	fd:close()
	if not ok then
		print(err)
	end
end

rdb.sethook(function(event, line)
	if event == "traceback" then
		launch_console()
	end
end)
