local ecs = ...
local world = ecs.world

local fbmgr             = require "framebuffer_mgr"
local viewidmgr         = require "viewid_mgr"
local isys_properties   = world:interface "ant.render|system_properties"
local ientity           = world:interface "ant.render|entity"
local irender           = world:interface "ant.render|irender"
local irq               = world:interface "ant.render|irenderqueue"

local pp_sys            = ecs.system "postprocess_system"
local ipp = ecs.interface "postprocess"

local techniques = {}
local quad_mesh

local function local_postprocess_views(num)
    local viewids = {}
    local name = "postprocess"
    for i=1, num do
        viewids[#viewids+1] = viewidmgr.get(name .. i)
    end
    return viewids
end

local postprocess_viewids = local_postprocess_views(10)

local viewid_idx = 0
local function next_viewid()
    viewid_idx = viewid_idx + 1
    return postprocess_viewids[viewid_idx]
end

local function reset_viewid_idx()
    viewid_idx = 0
end

function pp_sys:init()
    quad_mesh = ientity.quad_mesh {x=-1, y=-1, w=2, h=2}

end

local pp_lastinput
function pp_sys:post_init()
    pp_lastinput = ipp.get_rbhandle(fbmgr.get_fb_idx(viewidmgr.get "main_view"), 1)
end

local function render_pass(lastinput, out_viewid, pass)
    local input = pass.input or lastinput
    local output = pass.output
    if input == output then
        error("input and output as same render buffer handle")
    end

    irq.update_rendertarget(pass.render_target)

    local ppinput = isys_properties.get "s_postprocess_input"
    ppinput.texture.handle = output

    irender.draw(out_viewid, pass.renderitem)
    return output
end

local function iter_tech(tech)
    local reorders, passes = tech.reorders, tech.passes
    if reorders == nil then
        return ipairs(tech.passes)
    end

    return function (t, idx)
        idx = idx + 1
        local n = t[idx]
        if n then
            return passes[n]
        end
    end, reorders, 0
end

function pp_sys:combine_postprocess()
    local lastinput = pp_lastinput
    reset_viewid_idx()
    for _, tech in ipairs(techniques) do
        for _, pass in iter_tech(tech) do
            pp_lastinput = render_pass(lastinput, next_viewid(), pass)
        end
    end
end

function ipp.main_rb_size(main_fbidx)
    main_fbidx = main_fbidx or fbmgr.get_fb_idx(viewidmgr.get "main_view")

    local fb = fbmgr.get(main_fbidx)
    local rb = fbmgr.get_rb(fb[1])
    
    assert(rb.format:match "RGBA")
    return rb.w, rb.h
end

function ipp.get_rbhandle(fbidx, rbidx)
    local fb = fbmgr.get_fb(fbidx)
    return fbmgr.get_rb(fb[rbidx]).handle
end

function ipp.techniques()
    return techniques
end

function ipp.add_technique(tech)
    techniques[#techniques+1] = tech
end

function ipp.quad_mesh()
    return quad_mesh
end

function ipp.create_pass(material, rt, output, name)
    local eid = world:create_entity {
        policy = {"ant.render|simplerender"},
        data = {
            simplemesh = quad_mesh,
            material = material,
            state = 0,
        }
    }

    return {
        name        = name,
        renderitem  = world[eid]._rendercache,
        render_target = rt,
        output      = output,
        eid         = eid,
    }
end
