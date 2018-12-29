local vfs = require "vfs"

local path_mt = {}
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
    return lft == rht
end

function path_mt:string()
    return self._value
end

function path_mt:filename()
    return constructor(self._value:match("[/]?([%w_.-]*)$"))
end

function path_mt:parent_path()
    return constructor(self._value:match("^(.+)/[%w_.-]*$"))
end

function path_mt:stem()
    return constructor(self._value:match("[/]?([%w_.-]+)%.[%w_-]*$") or self._value:match("[/]?([.]?[%w_-]*)$"))
end

function path_mt:extension()
    return constructor(self._value:match("[^/](%.[%w_-]*)$"))
end

function path_mt:remove_filename()
    self._value = self._value:match("^(.+/)[%w_.-]*$")
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

function path_mt:is_absolute()
    return self._value:sub(1,1) == '/'
end

function path_mt:is_relative()
    return self._value:sub(1,1) ~= '/'
end

function path_mt:list_directory()
    local list = vfs.list(self._value)
    local n = 1
    return function()
        if not list[n] then
            return
        end
        local r = list[n]
        n = n + 1
        return self / r[1]
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

local fs = {}

fs.path = constructor

function fs.current_path()
    return constructor('/vfs/')
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

return fs
