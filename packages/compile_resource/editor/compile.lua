local fs    = require "filesystem"
local lfs   = require "filesystem.local"
local sha1  = require "editor.hash".sha1
local datalist = require "datalist"
local config    = require "editor.config"

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function readfile(filename)
	local f = assert(lfs.open(filename))
	local data = f:read "a"
	f:close()
	return data
end

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local function readconfig(filename)
    return datalist.parse(readfile(filename))
end

local function do_build(output)
    local depfile = output / ".dep"
    if not lfs.exists(depfile) then
        return
    end
	for _, dep in ipairs(readconfig(depfile)) do
        local timestamp, filename = dep[1], lfs.path(dep[2])
        if timestamp == 0 then
            if lfs.exists(filename) then
                return
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return
            end
        end
	end
	return true
end

local function create_depfile(filename, deps)
    local w = {}
    for _, file in ipairs(deps) do
        local path = lfs.path(file)
        if lfs.exists(path) then
            w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(path), lfs.absolute(path):string())
        else
            w[#w+1] = ("{0, %q}"):format(lfs.absolute(path):string())
        end
    end
    writefile(filename, table.concat(w, "\n"))
end

local compile

local function absolute_path(base, path)
	if path:sub(1,1) == "/" then
		return compile(path)
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local function do_compile(input, output)
    local inputstr = input:string()
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    lfs.create_directory(output)
    local ok, err = cfg.compiler(input, output, cfg.setting, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
end

local function compile_file(input)
    local inputstr = input:string()
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local output = cfg.binpath / get_filename(inputstr:lower())
    if not do_build(output) then
        lfs.create_directory(output)
        local ok, deps = cfg.compiler(input, output, cfg.setting, function (path)
            return absolute_path(input, path)
        end)
        if not ok then
            local err = deps
            error("compile failed: " .. input:string() .. "\n" .. err)
        end
        create_depfile(output / ".dep", deps or {})
    end
    return output
end

function compile(pathstring)
    local pos = pathstring:find("|", 1, true)
    if pos then
        local resource = fs.path(pathstring:sub(1,pos-1)):localpath()
        return compile_file(resource) / pathstring:sub(pos+1):gsub("|", "/")
    else
        return fs.path(pathstring):localpath()
    end
end

local set_setting = config.set

return {
    set_setting = set_setting,
    do_compile = do_compile,
    compile = compile,
    compile_file = compile_file,
}
