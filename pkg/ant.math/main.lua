local init_constant = require 'constant'
local init_util = require 'util'

local function init(math3d)
    local constant = init_constant(math3d)
    local util = init_util(math3d, constant)
    math3d.ext_util = util
    math3d.ext_constant = constant
end

--!!DEBUG
--require 'mathref'

local math3d = require 'math3d'
init(math3d)

return {
    init = init,
    util = math3d.ext_util,
    constant = math3d.ext_constant,
    adapter = require "adapter",
}
