local pm = require "antpm"
local vfs = require "filesystem"

local path_mt = {}
path_mt.__name = 'pkg-filesystem'
path_mt.__index = path_mt

local function constructor(str)
    return setmetatable({_value = str or ""}, path_mt)
end

local function normalize(fullname)
    local first = (fullname:sub(1, 2) == "//") and "//" or ""
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
    local root = (fullname:sub(1, 2) == "//") and "//" or ""
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

local function vfspath(self)
    assert(self:is_absolute())
    local value = self._value
    local pos = value:find('/', 3, true)
    if not pos then
        local root = pm.find(value:sub(3))
        if not root then
		    error(("No file '%s'"):format(value))
            return
        end
        return root
    end
	local root = pm.find(value:sub(3, pos-1))
	if not root then
        error(("No file '%s'"):format(value))
		return
	end
    return root / value:sub(pos+1)
end

function path_mt:__tostring()
    return self._value
end

function path_mt:__div(other)
    other = (type(other) == 'string') and other or other._value
    if other:sub(1, 1) == '//' then
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
    return self._value:sub(1,2) == '//'
end

function path_mt:is_relative()
    return self._value:sub(1,2) ~= '//'
end

function path_mt:list_directory()
    local next = vfspath(self):list_directory()
    local name
    return function()
        name = next(name)
        if not name then
            return
        end
        return self / name:filename():string()
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
    return vfspath(self):localpath()
end

-- TODO: delete
function path_mt:vfspath()
    return vfspath(self)
end

function path_mt:root_name()
    if not self:is_absolute() then
        return constructor('')
    end
    local value = self._value
    local pos = value:find('/', 3, true)
    if not pos then
        return constructor(value)
    end
    return constructor(value:sub(1, pos-1))
end

local fs = {}

fs.path = constructor

function fs.current_path()
    error 'Not implemented'
end

function fs.exists(path)
    return vfs.exists(vfspath(path))
end

function fs.is_directory(path)
    return vfs.is_directory(vfspath(path))
end

function fs.is_regular_file(path)
    return vfs.is_regular_file(vfspath(path))
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
    if path:sub(1, 2) == '//' then
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

fs.pkg = true

local fsutil = require 'filesystem.fsutil'
return fsutil(fs)
