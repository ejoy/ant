local registry = require "registry"

local function apply(self, s)
    self.setting = s
end

return {
    create = registry.create,
    apply = apply,
    setting = require "setting"
}
