local cr = import_package "ant.compile_resource"
local datalist = require "datalist"

local function loader(filename)
	return datalist.parse(cr.read_file(filename))
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
