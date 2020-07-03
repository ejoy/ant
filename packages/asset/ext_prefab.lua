local cr = import_package "ant.compile_resource"
local datalist = require "datalist"

local function loader(filename, world)
	local data = datalist.parse(cr.read_file(filename))
	return world:create_template(data)
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
