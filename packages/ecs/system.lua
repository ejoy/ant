local system = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

local function spiltName(pkg, fullname)
	local package, name = fullname:match "^([^|]*)|(.*)$"
	if not package then
		return pkg, fullname
	end
	return package, name
end

local function get_singleton(sys, c)
	local s = {}
	for _, pkg_system in pairs(sys) do
		for _,v in pairs(pkg_system) do
			if v.singleton then
				for _, singleton_name in ipairs(v.singleton) do
					local package, name = spiltName(v.package, singleton_name)
					local fullname = package.."|"..name
					local singleton_typeobject = c[package][name]
					if not singleton_typeobject then
						error(singleton_name .. " is not defined")
					end
					if s[fullname] == nil then
						log.info("New singleton", fullname)
						local init = singleton_typeobject.method.init
						s[fullname] = init and init() or {}
					end
				end
			end
		end
	end
	return s
end

local function gen_proxy(v, singletons)
	if not v.singleton then
		return {}
	end
	local lst = {}
	local inst = {}
	for _, singleton_name in ipairs(v.singleton) do
		local package, name = spiltName(v.package, singleton_name)
		local fullname = package.."|"..name
		if lst[name] == true then
			inst[fullname] = singletons[fullname]
		elseif lst[name] then
			inst[lst[name]] = inst[name]
			inst[fullname] = singletons[fullname]
			inst[name] = nil
			lst[name] = true
		else
			inst[name] = singletons[fullname]
			lst[name] = fullname
		end
	end
	return inst
end

local function create_proxy(sys, c)
	local singletons = get_singleton(sys, c)
	local p = {}
	for _, pkg_system in pairs(sys) do
		for system_name, system_typeobject in pairs(pkg_system) do
			p[system_name] = gen_proxy(system_typeobject, singletons)
		end
	end
	return p
end

local function solve_depend(res, step, pipeline)
	for _, v in ipairs(pipeline) do
		if type(v) == "string" then
			if step[v] == false then
				error(("pipeline has duplicate step `%s`"):format(v))
			elseif step[v] ~= nil then
				table_append(res, step[v])
				step[v] = false
			end
		elseif type(v) == "table" then
			solve_depend(res, step, v)
		end
	end
end

local function find_entry(pipeline, what)
	for _, v in ipairs(pipeline) do
		if type(v) == "table" then
			if v.name == what then
				return v
			end
			local res = find_entry(v, what)
			if res then
				return res
			end
		end
	end
end

function system.init(sys, singleton, pipeline)
	local mark = {}
	local res = setmetatable({}, {__index = function(t,k)
		local obj = {}
		t[k] = obj
		mark[k] = true
		return obj
	end})
	for _, pkg_system in sortpairs(sys) do
		for sys_name, s in sortpairs(pkg_system) do
			for step_name, func in pairs(s.method) do
				table.insert(res[step_name], { sys_name, func })
			end
		end
	end
	setmetatable(res, nil)

	local function check(pl)
		for _, v in ipairs(pl) do
			if type(v) == "string" then
				mark[v] = nil
			elseif type(v) == "table" then
				check(v)
			end
		end
	end
	check(pipeline)

	for name in pairs(mark) do
		error(("pipeline is missing step `%s`, which is defined in system `%s`"):format(name, res[name][1][1]))
	end
	return {
		steps = res,
		pipeline = pipeline,
		proxy = create_proxy(sys, singleton),
	}
end

function system.lists(sys, what)
	local subpipeline = find_entry(sys.pipeline, what)
	if not subpipeline then
		return
	end
	local res = {}
	solve_depend(res, sys.steps, subpipeline)
	return res
end

local switch_mt = {}; switch_mt.__index = switch_mt

function switch_mt:enable(name, enable)
	if enable ~= false then
		enable = nil
	end
	if self[name] ~= enable then
		self.__needupdate = true
		self[name] = enable
	end
end

function switch_mt:update()
	if self.__needupdate then
		local index = 1
		local all = self.__all
		local list = self.__list
		for i = 1, #all do
			local name = all[i][1]
			if self[name] ~= false then
				-- enable it
				list[index] = all[i]
				index = index + 1
			end
		end
		for i = index, #list do
			list[i] = nil
		end
		self.__needupdate = nil
	end
end

function system.list_switch(list)
	local all_list = {}
	for k,v in pairs(list) do
		all_list[k] = v
	end
	return setmetatable({
		__list = list,
		__all = all_list,
	} , switch_mt )
end

return system
