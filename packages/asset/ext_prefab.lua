local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local function loader(filename, world)
	local data = serialize.parse(filename, cr.read_file(filename))
	return world:create_template(data)
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
