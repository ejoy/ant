local compile = require "editor.material.compile"
local depends = require "editor.depends"
local lfs = require "filesystem.local"
local datalist = require "datalist"
local parallel_task = require "editor.parallel_task"

local function readfile(filename)
	local f <close> = assert(lfs.open(filename, "r"))
	return f:read "a"
end

local function readdatalist(filepath)
	return datalist.parse(readfile(filepath), function(args)
		return args[2]
	end)
end

return function(input, output, localpath)
    local mat = readdatalist(input)
    local depfiles = {}
    local tasks = parallel_task.new()
    compile(tasks, depfiles, mat, output, localpath)
    parallel_task.wait(tasks)
    depends.add(depfiles, localpath "/settings")
    return true, depfiles
end
