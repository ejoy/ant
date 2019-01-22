local posixfs = require 'filesystem.posix'

local path_mt = {}
path_mt.__name = 'filesystem'
path_mt.__index = path_mt

local function constructor(str)
    return setmetatable({_value = str or ""}, path_mt)
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

function path_mt:__eq(other)
    local lft = normalize(self._value)
    local rht = normalize(other._value)
    return lft:lower() == rht:lower()
end

function path_mt:string()
    return self._value
end

function path_mt:filename()
    return constructor(self._value:match("[/]?([%w*?_.-]*)$"))
end

function path_mt:parent_path()
    return constructor(self._value:match("^(.+)/[%w*?_.-]*$"))
end

function path_mt:stem()
    return constructor(self._value:match("[/]?([%w*?_.-]+)%.[%w*?_-]*$") or self._value:match("[/]?([.]?[%w*?_-]*)$"))
end

function path_mt:extension()
    return constructor(self._value:match("[^/](%.[%w*?_-]*)$"))
end

function path_mt:remove_filename()
    self._value = self._value:match("^(.+/)[%w*?_.-]*$") or ""
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
    local selfext = self._value:match("[^/](%.[%w*?_-]*)$") or ""
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
    local next = posixfs.dir(self._value)
    return function()
        local v
        repeat
            v = next()
        until v ~= '.' and v ~= '..'
        if v == nil then
            return
        end
        return self / v
    end
end

function path_mt:permissions()
    return posixfs.permissions(self._value)
end

function path_mt:add_permissions(prms)
    local old = posixfs.permissions(self._value)
    local new = prms | old
    if not posixfs.permissions(self._value, new) then
        return old
    end
    return new
end

function path_mt:remove_permissions(prms)
    local old = posixfs.permissions(self._value)
    local new = (~prms) & old
    if not posixfs.permissions(self._value, new) then
        return old
    end
    return new
end

local fs = {}

fs.path = constructor

function fs.current_path()
    return constructor(posixfs.getcwd())
end

function fs.exists(path)
    return posixfs.stat(path._value) ~= nil
end

function fs.is_directory(path)
    return posixfs.stat(path._value) == 'dir'
end

function fs.is_regular_file(path)
    return posixfs.stat(path._value) == 'file'
end

function fs.rename(from, to)
    assert(os.rename(from._value, to._value))
end

function fs.remove(path)
    if posixfs.stat(path._value) == nil then
        return false
    end
    assert(os.remove(path._value))
    return true
end

function fs.remove_all(dir)
    local stat = posixfs.stat(dir._value)
    if stat == nil then
        return 0
    elseif stat ~= 'dir' then
        local ok = os.remove(dir._value)
        return ok and 1 or 0
    end
    local n = 0
    for path in dir:list_directory() do
        n = n + fs.remove_all(path)
    end
    local ok = os.remove(dir._value)
    return n + (ok and 1 or 0)
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

function fs.create_directory(path)
    assert(posixfs.mkdir(path._value) == true)
    return true
end

local function create_directories(path)
    local parent = path:parent_path()
	if not fs.exists(parent) then
        if not fs.create_directories(parent) then
            return false
        end
	end
    return posixfs.mkdir(path._value)
end

function fs.create_directories(path)
    return create_directories(fs.absolute(path))
end

function fs.copy_file(from, to, overwritten)
    if not overwritten then
        assert(not fs.exists(to), to)
    end
    local fromf = assert(io.open(from._value, "rb"))
    local tof = assert(io.open(to._value, "wb"))
    tof:write(fromf:read "a")
    fromf:close()
    tof:close()
end

function fs.last_write_time(path, newtime)
    return posixfs.last_write_time(path._value, newtime)
end

function fs.exe_path()
    return constructor(posixfs.exe_path())
end

function fs.dll_path()
    return constructor(posixfs.dll_path())
end

function fs.filelock(path)
    return posixfs.filelock(path._value)
end

return fs
