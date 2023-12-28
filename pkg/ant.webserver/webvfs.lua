local function copy_fs(fsname)
	local fs = {}
	local localfs = require(fsname)
	for k,v in pairs(localfs) do
		fs[k] = v
	end
	return fs
end

local function local_reader(pathname)
	local f = assert(io.open(pathname, "rb"))
	local function reader()
		local bytes = f:read(4096)
		if bytes then
			return bytes
		else
			f:close()
		end
	end
	return reader
end

local vfs = require "vfs"
local fastio = require "fastio"

local function vfs_reader(pathname)
	local content = assert(vfs.read(pathname))
	local function reader()
		if content then
			local r = fastio.tostring(content)
			content = nil
			return r
		end
	end
	return reader
end

local FS = {
	vfs = copy_fs "filesystem",
	localfs = copy_fs "bee.filesystem",
} ; do
	FS.vfs.reader = vfs_reader
	FS.localfs.reader = local_reader
end

local M = {}

local html_header = [[
<html>
<head><meta charset="utf-8"></head>
<body>
<ul>
]]
local html_footer = [[
</ul>
</body>
]]

local plaintext = "text/plain;charset=utf-8"

local content_text_types = {
    -- ecs
    [".prefab"] = plaintext,
    [".ecs"] = plaintext,
    -- script
    [".lua"] = plaintext,
    -- ui
    [".css"] = plaintext,
    --[".html"] = plaintext,
    -- animation
    [".event"] = plaintext,
    [".anim"] = plaintext,
    -- compiled resource
    [".ant"] = plaintext,
    [".state"] = plaintext,
	-- shader
	[".sc"] = plaintext,
	[".sh"] = plaintext,
	-- local file
	[".log"] = plaintext,
	[".json"] = plaintext,
	-- for html
	[".html"] = "text/html",
	[".js"] = "text/html",
	[".gif"] = "image/gif",
	[".jpg"] = "image/jpeg",
	[".png"] = "image/png",
}

local function gen_get(fs)
	local function get_file(path)
		local ext = path:extension():string():lower()
		local content = fs.reader(path:string())
		local ctype = content_text_types[ext]
		if not ctype then
			if not ext:find("\0", 1, true) then
				ctype = plaintext
			end
		end
		local header = {
			["Content-Type"] = ctype or "application/octet-stream"
		}
		return content , header
	end

	local function get_dir(path, url, name)
		local filelist = {}
		for file, file_status in fs.pairs(path) do
			local t = file_status:is_directory() and "d" or "f"
			table.insert(filelist, t .. file:filename():string())
		end
		table.sort(filelist)
		local list = { html_header }
		for _, filename in ipairs(filelist) do
			local t , filename = filename:sub(1,1), filename:sub(2)
			local slash = t == "d" and "/" or ""
			table.insert(list, ('<li><a href="%s%s%s">%s%s</a></li>'):format(url, name, filename, filename, slash))
		end
		table.insert(list, html_footer)
		return table.concat(list, "\n")
	end

	local function get_path(path, url, name)
		if not fs.exists(path) then
			return
		end
		if fs.is_directory(path) then
			local index = path / "index.html"
			if fs.exists(index) then
				return get_file(index)
			else
				if name ~= "" then
					name = name .. "/"
				end
				return get_dir(path, url, name)
			end
		else
			return get_file(path)
		end
	end

	return get_path
end

local get_path = {}; do
	for k,v in pairs(FS) do
		get_path[k] = gen_get(v)
	end
end

local function get_directory(what)
	local directory = require "directory"
	if what == "log" then
		return directory.app_path():string()
	elseif what == "app" then
		return directory.app_path():string()
	end
end

-- path : abc
-- url_path : /vfs
-- vfs_path : web
-- url : vfs/abc
-- vfs : web/abc
function M.get(fsname, path, url_path, vfs_path)
	local fullpath = path == "" and vfs_path or (vfs_path .. path)
	local fs = FS[fsname]
	if not fs then
		fullpath = assert(get_directory(fsname)) .. fullpath
		fsname = "localfs"
		fs = FS.localfs
	end
	local pathname = FS[fsname].path(fullpath)
	local data, header = get_path[fsname](pathname, url_path, path)
	if data then
		return 200, data, header
	else
		return 403, ("ERROR 403 : %s not found"):format(url_path)
	end
end

return M