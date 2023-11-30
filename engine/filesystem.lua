local lfs = require "bee.filesystem"
local vfs = require "vfs"

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
    if fullname == "/" then
        return "/"
    end
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

function path_mt:normalize()
    self._value = normalize(self._value)
    return self
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

if __ANT_EDITOR__ then
    --TODO: remove it
    function path_mt:localpath()
        local localpath = vfs.realpath(normalize(self._value)) or error ("could not be find local path: ".. self._value)
        return lfs.path(localpath)
    end
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
    return vfs.type(path._value) ~= 'dir'
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

local filestatus = {}
filestatus.__index = filestatus

function filestatus:is_directory()
    local file_type = self[1].type
    return file_type == "d" or file_type == "r"
end

function fs.pairs(path)
    local value = path._value:gsub("(.-)/?$", "%1")
    local list = vfs.list(value .. "/")
    if not list then
        return function ()
        end
    end
    local name, status
    local status_obj = setmetatable({}, filestatus)
    return function()
        name, status = next(list, name)
        if not name then
            return
        end
        status_obj[1] = status
        return path / name, status_obj
    end
end

function fs.file_size(path)
    return lfs.file_size(path:localpath())
end

return fs
