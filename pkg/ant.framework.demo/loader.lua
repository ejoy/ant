local ecs = ...
local vfs = require "vfs"
local fastio = require "fastio"
local fs = require "filesystem"

local loader = {}

local demo_search_path = "$/?.lua:$/?/init.lua"

local function set_path(path)
	demo_search_path = demo_search_path:gsub("%$", path)
end

local demo_env

local function runfile(filename)
	local mem, symbol = vfs.read(filename)
	if mem then
		local func, err = fastio.loadlua(mem, symbol, demo_env)
		if not func then
			error ("Error loading file : " .. filename .. "\n" .. err)
		end
		return func() or true
	end
end

local function demo_require(name)
	local m = package.loaded[name]
	if m ~= nil then
		return m
	end
	m = package.preload[name]
	if m ~= nil then
		return m
	end
	
	local path_name = name:gsub("%.", "/")

	for pat in demo_search_path:gmatch "[^:]+" do
		local filename = pat:gsub("?", path_name)
		local r = runfile(filename)
		if r then
			package.loaded[name] = r
			return r
		end
	end
	
	return require(name)
end

function loader.key_callback(callback)
	if callback then
		local keyboard = ecs.require "keyboard"
		keyboard.key_callback(callback)
	end
end

function loader.mouse_callback(callback)
	if callback then
		local mouse = ecs.require "mouse"
		mouse.mouse_callback(callback)
	end
end

function loader.load(args)
	local fullpath = fs.path(args.path)
	set_path(fullpath:parent_path():string() or error "Must set .path")
	demo_env = setmetatable( {} , { __index = _G } )
	demo_env._G = env
	demo_env.require = demo_require
	demo_env.print_r = require "print_r"
	demo_env.ant = require "api" (ecs, args)
	local t = runfile (args.path)
	return t
end

return loader