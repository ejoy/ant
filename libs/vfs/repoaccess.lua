local access = {}

local fs = require "filesystem"

function access.readmount(filename)
	local f = io.open(filename, "rb")
	local ret = {}
	if not f then
		return ret
	end
	for line in f:lines() do
		local name, path = line:match "^%s*(.-)%s*:%s*(.-)%s*$"
		if name == nil then
			if not (line:match "^%s*#" or line:match "^%s*$") then
				f:close()
				error ("Invalid .mount file : " .. line)
			end
		end
		path = path:gsub("%s*#.*$","")	-- strip comment
		ret[name] = path
	end
	f:close()
	return ret
end

function access.mountname(mountpoint)
	local mountname = {}

	for name, path in pairs(mountpoint) do
		if name ~= '' then
			table.insert(mountname, name)
		end
		mountpoint[name] = path
	end
	table.sort(mountname, function(a,b) return a>b end)
	return mountname
end

function access.realpath(repo, pathname)
	pathname = pathname:match "^/?(.-)/?$"
	local mountname = repo._mountname
	for _, mpath in ipairs(repo._mountname) do
		if pathname == mpath then
			return repo._mountpoint[mpath]
		end
		local n = #mpath + 1
		if pathname:sub(1,n) == mpath .. '/' then
			return repo._mountpoint[mpath] .. "/" .. pathname:sub(n+1)
		end
	end
	return repo._root .. pathname
end

function access.list_files(repo, filepath)
	local rpath = access.realpath(repo, filepath)
	local files = {}
	for name in fs.dir(rpath) do
		if name:sub(1,1) ~= '.' then	-- ignore .xxx file
			files[name] = true
		end
	end
	filepath = (filepath:match "^/?(.-)/?$") .. "/"
	if filepath == '/' then
		-- root path
		for mountname in pairs(repo._mountpoint) do
			if mountname ~= ''  and not mountname:find("/",1,true) then
				files[mountname] = true
			end
		end
	else
		local n = #filepath
		for mountname in pairs(repo._mountpoint) do
			if mountname:sub(1,n) == filepath then
				local name = mountname:sub(n+1)
				if not name:find("/",1,true) then
					files[name] = true
				end
			end
		end
	end
	return files
end

return access
