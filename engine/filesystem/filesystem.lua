local lfs = require "filesystem.local"
local vfs = require "vfs.simplefs"
local nio = io

local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end

local function vfs_open(filename, mode)
    if mode ~= nil and mode ~= 'r' and mode ~= 'rb' then
        return nil, ('%s:Permission denied.'):format(filename)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        return nil, ('%s:No such file or directory.'):format(filename)
    end
    local f, err, ec = nio.open(real_filename, mode)
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end

local function vfs_lines(filename, ...)
    if type(filename) ~= 'string' then
        return nio.lines(filename, ...)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        error(('%s:No such file or directory.'):format(filename))
    end
    local ok, res = pcall(nio.lines, real_filename, ...)
    if ok then
        return res
    end
    error(errmsg(res, filename, real_filename))
end

local function vfs_loadfile(path, ...)
    local f, err = vfs_open(path, 'r')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@' .. path, ...)
end

local function vfs_dofile(path)
    local f, err = vfs_loadfile(path)
    if not f then
        error(err)
    end
    return f()
end

local path_mt = {}
path_mt.__name = 'vfs-filesystem'
path_mt.__index = path_mt

local function constructor(str)
    if str == nil then
        return setmetatable({_value = "" }, path_mt)
    end
    if type(str) == "string" then
        return setmetatable({_value = str }, path_mt)
    end
    return setmetatable({_value = str._value }, path_mt)
end

local function normalize(fullname)
    local first = (fullname:sub(1, 1) == "/") and "/" or ""
    local last = (fullname:sub(-1, -1) == "/") and "/" or ""
	local t = {}
	for m in fullname:gmatch("([^/\\]+)[/\\]?") do
		if m == ".." and next(t) then
			table.remove(t, #t)
		elseif m ~= "." then
			table.insert(t, m)
		end
	end
	return first .. table.concat(t, "/") .. last
end

local function normalize_split(fullname)
    local root = (fullname:sub(1, 1) == "/") and "/" or ""
    local stack = {}
	for elem in fullname:gmatch("([^/\\]+)[/\\]?") do
        if #elem == 0 and #stack ~= 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem
        end
    end
    return root, stack
end

function path_mt:__tostring()
    return self._value
end

function path_mt:__div(other)
    other = (type(other) == 'string') and other or other._value
    if other:sub(1, 1) == '/' then
        return constructor(other)
    end
    local value = self._value:gsub("(.-)/?$", "%1")
    return constructor(value .. '/' .. other)
end

function path_mt:__concat(other)
    other = (type(other) == 'string') and other or other._value
    return constructor(self._value .. other)
end

function path_mt:__eq(other)
    local lft = normalize(self._value)
    local rht = normalize(other._value)
    return lft == rht
end

function path_mt:string()
    return self._value
end

function path_mt:filename()
    return constructor(self._value:match("[/]?([^/]*)$"))
end

function path_mt:parent_path()
    return constructor(self._value:match("^(.+)/[^/]*$"))
end

function path_mt:stem()
    return constructor(self._value:match("[/]?([%w*?_.%-]+)%.[%w*?_%-]*$") or self._value:match("[/]?([.]?[%w*?_%-]*)$"))
end

function path_mt:extension()
    return constructor(self._value:match("[^/](%.[%w*?_%-]*)$"))
end

function path_mt:remove_filename()
    self._value = self._value:match("^(.+/)[%w*?_.%-]*$") or ""
    return self
end

function path_mt:replace_extension(ext)
    local stem = self:stem()
    self:remove_filename()
    if ext:sub(1, 1) ~= '.' then
        ext = '.' .. ext
    end
    self._value = self._value .. stem._value .. ext
    return self
end

function path_mt:equal_extension(ext)
    ext = (type(ext) == 'string') and ext or ext._value
    local selfext = self._value:match("[^/](%.[%w*?_%-]*)$") or ""
    if selfext == "" then
        return ext == ""
    end
    ext = (ext:sub(1,1) ~= '.') and ('.'..ext) or ext
    return selfext == ext
end

function path_mt:is_absolute()
    return self._value:sub(1,1) == '/'
end

function path_mt:is_relative()
    return self._value:sub(1,1) ~= '/'
end

function path_mt:list_directory()
    local next = vfs.each(self._value)
    local name
    return function()
        name = next()
        if not name then
            return
        end
        return self / name
    end
end

function path_mt:permissions()
    error 'Not implemented'
end

function path_mt:add_permissions()
    error 'Not implemented'
end

function path_mt:remove_permissions()
    error 'Not implemented'
end

function path_mt:localpath()
    return lfs.path(vfs.realpath(self._value))
end

function path_mt:package_name()
    local root, stack = normalize_split(self._value)
    if root ~= "/" or #stack <= 1 or stack[1] ~= "pkg" then
        error("Invalid package path")
    end
    return stack[2]
end

local fs = {}

fs.path = constructor

function fs.current_path()
    error 'Not implemented'
end

function fs.exists(path)
    return vfs.type(path._value) ~= nil
end

function fs.is_directory(path)
    return vfs.type(path._value) == 'dir'
end

function fs.is_regular_file(path)
    return vfs.type(path._value) == 'file'
end

function fs.rename()
    error 'Not implemented'
end

function fs.remove()
    error 'Not implemented'
end

function fs.remove_all()
    error 'Not implemented'
end

function fs.absolute(path, base)
    path = normalize(path._value)
    if path:sub(1, 1) == '/' then
        return constructor(path)
    end
    base = base or fs.current_path()
    path = base / path
    return constructor(normalize(path._value))
end

function fs.relative(path, base)
    --TODO root
    base = base or fs.current_path()
    local _, pstack = normalize_split(path._value)
    local _, bstack = normalize_split(base._value)
    while #pstack > 0 and #bstack > 0 and pstack[1] == bstack[1] do
        table.remove(pstack, 1)
        table.remove(bstack, 1)
    end
    if #pstack == 0 and #bstack== 0 then
        return "./"
    end
    local s = {}
    for _ in ipairs(bstack) do
        s[#s+1] = '..'
    end
    for _, e in ipairs(pstack) do
        s[#s+1] = e
    end
    return constructor(table.concat(s, "/"))
end

function fs.create_directory()
    error 'Not implemented'
end

function fs.create_directories()
    error 'Not implemented'
end

function fs.copy_file()
    error 'Not implemented'
end

function fs.last_write_time()
    error 'Not implemented'
end

function fs.exe_path()
    error 'Not implemented'
end

function fs.dll_path()
    error 'Not implemented'
end

function fs.filelock()
    error 'Not implemented'
end

function fs.open(filepath, ...)
    return vfs_open(filepath:string(), ...)
end
function fs.lines(filepath, ...)
    return vfs_lines(filepath:string(), ...)
end

if __ANT_RUNTIME__ then
    function fs.loadfile(filepath, ...)
        return vfs_loadfile(filepath:string(), ...)
    end
    function fs.dofile(filepath)
        return vfs_dofile(filepath:string())
    end
else
    function fs.loadfile(filepath, ...)
        return loadfile(filepath:localpath():string(), ...)
    end
    function fs.dofile(filepath)
        return dofile(filepath:localpath():string())
    end
end

return fs
