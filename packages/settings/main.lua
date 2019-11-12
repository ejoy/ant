local registry = require "registry"

local function create(path, mode)
    return registry.create(path, mode)
end

return {
    create = create,
}
