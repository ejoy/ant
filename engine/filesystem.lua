local vfs = require "vfs"

local path_mt = {}
path_mt.__index = path_mt

local function constructor(str)
    return setmetatable({ _value = str or "" }, path_mt)
end

local function normalize(fullname)
    if fullname == "/" then
        return "/"
    end
    local first = (fullname:sub(1, 1) == "/") and "/" or ""
    local last = (fullname:sub(-1, -1) == "/") and "/" or ""
    local t = {}
    for m in fullname:gmatch "([^/]+)/?" do
        if m == ".." and #t > 0 then
            t[#t] = nil
        elseif m ~= "." then
            t[#t+1] = m
        end
    end
    return first .. table.concat(t, "/") .. last
end

local function concat(a, b)
    if b:sub(1, 1) == "/" then
        return constructor(b)
    end
    local value = a:gsub("/?$", "/")
    return constructor(value .. b)
end

function path_mt:__tostring()
    return self._value
end

function path_mt:__div(other)
    if type(other) ~= "string" then
        other = other._value
    end
    return concat(self._value,  other)
end

function path_mt:__concat(other)
    if type(other) ~= "string" then
        other = other._value
    end
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
    return constructor(self._value:match "/?([^/]*)$")
end

function path_mt:parent_path()
    return constructor(self._value:match "^(.+)/[^/]*$")
end

function path_mt:stem()
    return constructor(self._value:match "/?([%w*?_.%-]+)%.[%w*?_%-]*$" or self._value:match "/?(.?[%w*?_%-]*)$")
end

function path_mt:extension()
    return self._value:match "[^/](%.[%w*?_%-]*)$" or ""
end

function path_mt:remove_filename()
    self._value = self._value:match "^(.+/)[%w*?_.%-]*$" or ""
    return self
end

function path_mt:replace_extension(ext)
    local stem = self:stem()
    self:remove_filename()
    if ext:sub(1, 1) ~= "." then
        ext = "." .. ext
    end
    self._value = self._value .. stem._value .. ext
    return self
end

function path_mt:is_absolute()
    return self._value:sub(1,1) == "/"
end

function path_mt:is_relative()
    return self._value:sub(1,1) ~= "/"
end

function path_mt:lexically_normal()
    return constructor(normalize(self._value))
end

local fs = {}

function fs.path(str)
    if type(str) ~= "string" then
        str = str._value
    end
    return setmetatable({ _value = str }, path_mt)
end

function fs.exists(path)
    if type(path) ~= "string" then
        path = path._value
    end
    return vfs.type(path) ~= nil
end

function fs.is_directory(path)
    if type(path) ~= "string" then
        path = path._value
    end
    local status = vfs.type(path)
    return status == "d" or status == "r"
end

function fs.is_regular_file(path)
    if type(path) ~= "string" then
        path = path._value
    end
    return vfs.type(path) == "f"
end

local status_mt = {}
status_mt.__index = status_mt

function status_mt:is_directory()
    local status = self[1]
    return status == "d" or status == "r"
end

function status_mt:is_regular_file()
    local status = self[1]
    return status == "f"
end

function fs.pairs(path)
    if type(path) ~= "string" then
        path = path._value
    end
    local list = vfs.list(path:gsub("/?$", "/"))
    if not list then
        return function ()
        end
    end
    local name, status
    local status_obj = setmetatable({}, status_mt)
    return function()
        name, status = next(list, name)
        if not name then
            return
        end
        status_obj[1] = status
        return concat(path, name), status_obj
    end
end

return fs
