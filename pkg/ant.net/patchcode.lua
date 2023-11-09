local M = {}

function M.patch(chunks)
	local len = #chunks
	local index = 1
	local funcs = {}
	local function loadcode(name, code)
		local f = load(code)
		if funcs[name] then
			error ("Duplicate function " .. name)
		end
		funcs[name] = {
			name = name,
			func = f,
		}
	end
	local function restore_upvalue()
		for name, v in pairs(funcs) do
			local f = v.func
			local info = debug.getinfo(f, "u")
			for i = 1, info.nups do
				local name, v = debug.getupvalue(f, i)
				local uf = funcs[name]
				if not uf then
					if name ~= "_ENV" then
						error ("Missing upvalue " .. name .. " for function : " .. v.name)
					else
						debug.setupvalue(f, i, _ENV)
					end
				else
					debug.setupvalue(f, i, uf.func)
				end
			end
		end
	end
	while index <= len do
		local name, code, next_index = ("zs"):unpack(chunks, index)
		loadcode(name, code)
		index = next_index
	end
	restore_upvalue()
	local mainf = assert(funcs[""])
	mainf.func()
end

M.patchcode = string.dump(M.patch)

function M.dumpfuncs(f)
	local all_funcs = {}
	local chunks = {}
	local function dumpfunc(f, name)
		local last_name = all_funcs[f]
		if last_name then
			if last_name ~= name then
				error ("Function has more than one name : " .. last_name .. " " .. name)
			end
			return
		end
		all_funcs[f] = name
		table.insert(chunks, string.pack("zs", name, string.dump(f)))
		local index = 1
		while true do
			local uname, v = debug.getupvalue(f, index)
			if not uname then
				break
			end
			if type(v) ~= "function" then
				if uname ~= "_ENV" then
					error ("Upvalue " .. uname .. " for function " .. name .. " is not a function")
				end
			else
				dumpfunc(v, uname)
			end
			index = index + 1
		end
	end
	dumpfunc(f, "")
	return table.concat(chunks)
end

function M.find_upvalues(filter_name)
	local upvalues = {}
	local upvalues_f = {}
	local function func_upvalues(f)
		if upvalues_f[f] then
			return
		end
		upvalues_f[f] = true
		local t = debug.getinfo(f, "Su")
		if not t then
			return
		end
		local filter = t.short_src:find(filter_name, 1, true)
		for i = 1, t.nups do
			local name, uv = debug.getupvalue(f,i)
			if name ~= "_ENV" then
				if filter then
					local last = upvalues[name]
					if last == nil then
						upvalues[name] = uv
					elseif last ~= uv then
						-- conflict upvalue
						upvalues[name] = false
					end
				end
				local uvt = type(uv)
				if uvt == "function" then
					func_upvalues(uv)
				elseif uvt == "table" then
					for _, f in pairs(uv) do
						if type(f) == "function" then
							func_upvalues(f)
						end
					end
				end
			end
		end
	end
	local function all_upvalues()
		local level = 1
		while true do
			local t = debug.getinfo(level, "f")
			if t then
				func_upvalues(t.func)
			else
				break
			end
			level = level + 1
		end
	end
	all_upvalues()
	return upvalues
end

return M
