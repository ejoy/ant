local fg = {}

--TODO: framegraph have something duplicate function with render queue(and viewid in bgfx)
--if all the framegraph are compied, it did viewid's job for sort render submit.
--and each pass should conrespond to render pass in vulkan/metal
--beside this, framegraph should also resolve the render_target depend job, make one pass start after the depend pass
--we should remove some code in api level, but right now, we can use it in postprocess(postprocess queue only have some submits, and all this submit are done in lua level)
--but those postprocess stages depend on pre_depth/main_view passes, so we should setup here and let postprocess pass depend on them

local PASSES = {}

function fg.register_pass(name, passinfo)
    if PASSES[name] then
        error(("Already register pass:%s"):format(name))
    end

    assert(passinfo.init)
    assert(passinfo.run)

    -- local depends = passinfo.depends
    -- if depends then
    --     for _, d in ipairs(depends) do
    --         local _ = PASSES[d] or error(("Invalid depend pass:%s"):format(d))
    --     end
    -- end
    PASSES[name] = passinfo
end

function fg.pass(n)
    return assert(PASSES[n])
end

function fg.add_depend(n, d)
    local _ = PASSES[d] or error(("Invalid depend pass name:%s"):format(d))
    local p = PASSES[n] or error(("Pass: %s is not regist"):format(n))

    if not p.depends then
        p.depends = {}
    end
    p.depends[#p.depends+1] = d
end

local function find_depend(n, depends)
    for i, d in ipairs(depends) do
        if d == n then
            return i
        end
    end
end

local function check_insert_item(n, depends, inserthit)
    if not find_depend(n, depends) then
        if inserthit then
            return table.insert(depends, inserthit, n)
        end
        return table.insert(depends, n)
    end
end

local function insert_depend(n, p, depends, passes)
    local inserthit
    if p.depends then
        for _, dp in ipairs(p.depends) do
            local pp = passes[dp] or error(("Invalid depend:%s"):format(dp))
            inserthit = insert_depend(dp, pp, depends, passes)
            check_insert_item(n, depends, inserthit)
        end
    end
    check_insert_item(n, depends, inserthit)
end

local DEPEND_LISTS

local function _check_cycle_depend(p, marks, passes)
    local depends = p.depends
    if depends then
        for _, d in ipairs(depends) do
            if marks[d] then
                return true
            end
            marks[d] = true

            local pp = passes[d]
            if pp then
                return _check_cycle_depend(pp, marks, passes)
            end
        end
    end
end

local function check_cycle_depend(n, passes)
    return _check_cycle_depend(assert(passes[n]), {}, passes)
end

local function solve_depends(passes)
    local dependlist = {}
    for n, p in pairs(passes) do
        assert(not check_cycle_depend(n, passes), "detect cycle depend")
        insert_depend(n, p, dependlist, passes)
    end
    return dependlist
end

local function init_passes(list, passes)
    for _, n in ipairs(list) do
        passes[n]:init()
    end
end

function fg.compile()
    DEPEND_LISTS = solve_depends(PASSES)
    init_passes(DEPEND_LISTS, PASSES)
end

function fg.run()
    assert(DEPEND_LISTS, "Need compile before 'run'")

    for _, n in ipairs(DEPEND_LISTS) do
        local p = PASSES[n]
        p:run()
    end
end


if true then
    assert(check_cycle_depend("n1", {
        n1 = {depends = {"n2"}},
        n2 = {depends = {"n3"}},
        n3 = {depends = {"n1"}},
    }), "cycle depend")
    
    --[[
    in:
        n3
        |
        n2
       / \
      n1 n4
    out:
        n3 -> n2 -> n1/n4
    ]]
    
--[[     local l = solve_depends{
        n1 = {
            depends = {"n2"},
        },
        n2 = {
            depends = {"n3"},
        },
        n4 = {
            depends = {"n2"},
        },
        n3 = {}
    }
    assert(l[1] == "n3" and l[2] == "n2" and ((l[3] == "n1" or l[3] == "n4") or (l[4] == "n1" or l[4] == "n4")))
    ]]

    local l = solve_depends{
        n1 = {
            depends = {"n2", "n4"},
        },
        n2 = {
            depends = {"n3"},
        },
        n3 = {
            depends = {"n6"},
        },
        n4 = {
            depends = {"n6"},
        },
        n5 = {
            depends = {"n2"},
        },
        n6 = {
            depends = {}
        }
    }

end

return fg