local fg = {}

--TODO: framegraph have something duplicate function with render queue(and viewid in bgfx)
--if all the framegraph are compied, it did viewid's job for sort render submit.
--and each pass should conrespond to render pass in vulkan/metal
--beside this, framegraph should also resolve the render_target depend job, make one pass start after the depend pass
--we should remove some code in api level, but right now, we can use it in postprocess(postprocess queue only have some submits, and all this submit are done in lua level)
--but those postprocess stages depend on pre_depth/main_view passes, so we should setup here and let postprocess pass depend on them
--and there are no render pass concept right now(it's on developing), so begin/finish function defined in pass are not use

local PASSES = {}

function fg.register_pass(name, passinfo)
    if PASSES[name] then
        error(("Already register pass:%s"):format(name))
    end

    assert(passinfo.init)
    assert(passinfo.run)

    local dependname = passinfo.depend
    if dependname then
        local _ = PASSES[dependname] or error(("Invalid depend pass:%s"):format(dependname))
    end
    PASSES[name] = passinfo
end

function fg.pass(n)
    return assert(PASSES[n])
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
    if p.depend then
        local dp = passes[p.depend] or error(("Invalid depend:%s"):format(p.depend))
        inserthit = insert_depend(p.depend, dp, depends, passes)
    end
    
    check_insert_item(n, depends, inserthit)
end

local DEPEND_LISTS

local function check_cycle_depend(d, marks, passes)
    if d then
        if marks[d] then
            return true
        end
        marks[d] = true
        local p = passes[d]
        if p then
            return check_cycle_depend(p.depend, marks, passes)
        end
    end
end

local function solve_depends(passes)
    local dependlist = {}
    for n, p in pairs(passes) do
        assert(not check_cycle_depend(n, {}, passes), "detect cycle depend")
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
    DEPEND_LISTS = solve_depends()
    init_passes(DEPEND_LISTS, PASSES)
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


if true then
    assert(check_cycle_depend("n1", {}, {
        n1 = {depend = "n2"},
        n2 = {depend = "n3"},
        n3 = {depend = "n1"}
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
    
    local l = solve_depends{
        n1 = {
            depend = "n2",
        },
        n2 = {
            depend = "n3",
        },
        n4 = {
            depend = "n2",
        },
        n3 = {}
    }
    
    assert(l[1] == "n3" and l[2] == "n2" and ((l[3] == "n1" or l[3] == "n4") or (l[4] == "n1" or l[4] == "n4")))
end

return fg