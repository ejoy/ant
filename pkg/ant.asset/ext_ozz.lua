local aio = import_package "ant.io"
local ozz = require "ozz"

local function loader(filename)
	return ozz.load(aio.readall(filename))
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
