local platform = require 'platform'

return function (fs)
	local isvfs = fs.vfs
	local ispkg = fs.pkg
	local isloc = not isvfs and not ispkg
	local function native_method(name)
		if isvfs then
			local vfsio = require "vfsio"
			return vfsio[name]
		end
		if ispkg then
			local pkgio = require "pkgio"
			return pkgio[name]
		end
		local nativeio = require "nativeio"
        return nativeio[name]
	end

	function fs.open(filepath, ...)
		local m = native_method("open")
		return m(filepath:string(), ...)
	end
	function fs.lines(filepath, ...)
		local m = native_method("lines")
		return m(filepath:string(), ...)
	end

	if __ANT_RUNTIME__ then
		function fs.loadfile(filepath, ...)
			local m = native_method("loadfile")
			return m(filepath:string(), ...)
		end
		function fs.dofile(filepath)
			local m = native_method("dofile")
			return m(filepath:string())
		end
	else
		function fs.loadfile(filepath, ...)
			if not isloc then
				filepath = filepath:localpath()
			end
			return require "nativeio".loadfile(filepath:string(), ...)
		end
		function fs.dofile(filepath)
			if not isloc then
				filepath = filepath:localpath()
			end
			return require "nativeio".dofile(filepath:string())
		end
	end

	if not isloc then
		return fs
	end

    if platform.OS == 'Windows' then
        function fs.mydocs_path()
            return fs.path(os.getenv 'USERPROFILE') / 'Documents'
        end
    else
        function fs.mydocs_path()
            return fs.path(os.getenv 'HOME') / 'Documents'
        end
	end

	function fs.file_is_newer(check, base)
		if not fs.exists(base) and fs.exists(check) then
			return true
		end

		if fs.is_directory(check) or fs.is_directory(base) then
			return false
		end

		local checktime = fs.last_write_time(check)
		local basetime = fs.last_write_time(base)
		return checktime > basetime
	end

	function fs.listfiles(subfolder, files, filter_exts)
		if not fs.exists(subfolder) then
			return
		end
		for p in subfolder:list_directory() do
			local filepath = subfolder / p
			if fs.is_directory(filepath) then
				fs.listfiles(filepath, files, filter_exts)
			else
				if filter_exts then
					if type(filter_exts) == "function" then
						if filter_exts(filepath) then
							table.insert(files, filepath)
						end
					else
						assert(type(filter_exts) == "table")
						local ext = p:extension()
						for _, e in ipairs(filter_exts) do
							if ext:match(e) then
								table.insert(files, filepath)
							end
						end
					end

				else
					table.insert(files, filepath)
				end
			end
		end
	end

	local path_mt = debug.getmetatable(fs.path())
	if not path_mt.localpath then
		function path_mt:localpath()
			return self
		end
	end

    return fs
end
