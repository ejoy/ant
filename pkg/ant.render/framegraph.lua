local fg = {}

local pass_mt = {
    compile = function (self)
    end,
    init = function (self)
    end,
    run = function (self)
    end,
    begin = function (self)
    end,
    finish = function (self)
    end,
}

local PASSES = {}

function fg.register_pass(name, dependname, passinfo)
    if PASSES[name] then
        error(("Already register pass:%s"):format(name))
    end

    assert(passinfo.compile)
    assert(passinfo.init)
    assert(passinfo.run)

    local _ = PASSES[dependname] or error(("Invalid depend pass:%s"):format(dependname))
    passinfo.depend = dependname
    PASSES[name] = passinfo
end

local function insert_depend(n, depends)
    local p
    for idx, d in ipairs(depends) do
        if d == n then
            p = idx
            break
        end
    end

    table.insert(depends, p, n)
    return p+1
end

local DEPEND_LISTS

function fg.compile()
    DEPEND_LISTS = {}
    --solve depends
    for n, p in pairs(PASSES) do
        local where = insert_depend(n, DEPEND_LISTS)
        if p.depend then
            table.insert(DEPEND_LISTS, where, p.depend)
        end
    end

    for _, n in ipairs(DEPEND_LISTS) do
        local p = PASSES[n]
        p:init()
    end
end

function fg.run()
    assert(DEPEND_LISTS, "Need compile before 'run'")

    for _, n in ipairs(DEPEND_LISTS) do
        local p = PASSES[n]
        p:begin()
        p:run()
        p:finish()
    end
end

--test
--[[

--in render_system.lua
local render_sys = ecs.system "render_system"
function render_sys:init()
    local fg = ecs.require "ant.render|framegraph"
    fg.register_pass("scene", nil, {
        init = function (self)
            self.input = nil
            local mq = w:first "main_queue render_target:in"
            local fb = fbmgr.get(mq.render_target.fb_idx)
            self.output = fb.get_rb(fb, 1)
        end,

        begin = function (self)
            fg.begin(self)
        end,

        finish = function (self)
            fg.finish(self)
        end,

        run = function (self)
            --do nothing, submit code in c
        end,
    })
end

--in bloom.lua
local bloom_sys = ecs.system "bloom_system"

function bloom_sys:init_world()
    fg.register_pass("bloom", "scene", {
        init = function (self)
            
        end,
    })
end

]]

return fg