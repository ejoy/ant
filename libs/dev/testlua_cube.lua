local bgfx = require "bgfx"
local math3d = require "math3d"
local shader_mgr = require "render.resources.shader_mgr"

local ctx = {}
local time = 0

local stack = math3d.new()
local testcube = {}
local init_flag = false

function testcube.init(width, height, app_dir, bundle_path)

    ctx.width = width
    ctx.height = height

    local projmat = stack({type = "proj", fov = 60, aspect = ctx.width/ctx.height, n=0.1, f=100}, "m")
    local viewmat = stack({0,0,-35},{0,0,0}, "lm")

    print("math", type(projmat))
    bgfx.set_view_transform(0, viewmat, projmat)

    local vs_path = "vs_cubes"
    local fs_path = "fs_cubes"

    --load shaders
    ctx.prog = shader_mgr.programLoad(vs_path, fs_path, nil, app_dir.."/Common")

    ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
    ctx.vdecl = bgfx.vertex_decl {
        { "POSITION", 3, "FLOAT" },
        { "COLOR0", 4, "UINT8", true },
    }

    ctx.vb = bgfx.create_vertex_buffer({
        "fffd",
        -1.0,  1.0,  1.0, 0xff000000,
        1.0,  1.0,  1.0, 0xff0000ff,
        -1.0, -1.0,  1.0, 0xff00ff00,
        1.0, -1.0,  1.0, 0xff00ffff,
        -1.0,  1.0, -1.0, 0xffff0000,
        1.0,  1.0, -1.0, 0xffff00ff,
        -1.0, -1.0, -1.0, 0xffffff00,
        1.0, -1.0, -1.0, 0xffffffff,
    },
            ctx.vdecl)

    ctx.ib = bgfx.create_index_buffer{
        0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
    }

    ctx.width = width
    ctx.height = height

    init_flag = true
end


function testcube.mainloop()
    bgfx.touch(0)
    time = time + 0.5

    for yy = 0, 10 do
        for xx = 0, 6 do
            local cube_mat = stack({r = {time*0.21*xx, time*0.37*yy, 0}, t = {-9.0 + 3*xx, -15.0 + 3*yy, 0}}, "m")

            bgfx.set_transform(cube_mat)
            bgfx.set_vertex_buffer(ctx.vb)
            bgfx.set_index_buffer(ctx.ib)
            bgfx.set_state(ctx.state)
            bgfx.submit(0, ctx.prog)
        end
    end

    bgfx.frame()
end

function testcube.terminate()
    if init_flag then
        bgfx.destroy(ctx.vb)
        bgfx.destroy(ctx.ib)
        bgfx.destroy(ctx.prog)
    end
end

return testcube