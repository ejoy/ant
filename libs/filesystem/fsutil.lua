
local platform = require 'platform'

return function (fs)
	fs.vfs = __ANT_RUNTIME__ ~= nil
	local function native_method(name)
		if fs.vfs then
			local vfsio = require "vfsio"
			return vfsio[name]
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
						local ext = path.ext(p)
						for _, e in ipairs(filter_exts) do
							if ext == e then
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
    return fs
end
