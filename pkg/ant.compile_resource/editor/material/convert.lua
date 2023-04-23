local compile = require "editor.material.compile"
local depends = require "editor.depends"
local lfs = require "filesystem.local"
local datalist = require "datalist"

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
    local ok, deps = compile(mat, output, localpath)
    if not ok then
        return false, ("compile failed: " .. input:string() .. "\n\n" .. deps)
    end
    depends.add(deps, localpath "/settings")
    return true, deps
end
