-- Usage : require this module at your project start,
-- and put this line into first line of every submodule.
--
-- local require = import and import(...) or require

local loaded = package.loaded
local searchpath = package.searchpath

function import(modname)
	if modname then
		local prefix = modname:match "(.*%.).*$" or (modname .. ".")
		return function(name)
			local fullname = prefix .. name
			local m = loaded[fullname] or loaded[name]
			if m then
				return m
			end
			if searchpath(fullname, package.path) then
				return require(fullname)
			else
				return require(name)
			end
		end
	else
		return require
	end
end
