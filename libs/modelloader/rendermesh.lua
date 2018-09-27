--存放渲染参数
local bgfx = require "bgfx"
local shader_mgr = require "render.resources.shader_mgr"
local ru = require "render.util"
local asset = require "asset"

local render_mesh = {}
local ctx = {stats = {}}

local default_shader = { vs = "mesh/vs_mesh", fs = "mesh/fs_mesh"}

function render_mesh:InitRenderContext(file_path, shader)
    --暂时不提供太多可供选择的参数
    assert(file_path ~= nil, "file_path invalid")       --文件路径不可为空
    if (shader == nil) then        --shader可以为空,此时则采用默认shader
        shader = default_shader
    end

    print("Rendering mesh: " .. file_path)

    ctx.prog = shader_mgr.programLoad(shader.vs, shader.fs)
    ctx.mesh = assert(asset.load(file_path)).handle
    ctx.u_time = bgfx.create_uniform("u_time", "v4")
    ctx.state = bgfx.make_state{
        WRITE_MASK = "RGBAZ",
        DEPTH_TEST = "LESS",
        MSAA = true,
    }
end

function render_mesh:SubmitRenderMesh()
    bgfx.set_state(ctx.state)
    if(ctx.mesh ~= nil and ctx.prog ~= nil) then        
        local mesh = ctx.mesh
        local num = #mesh.groups
    
        for i=1, num do
            local g = mesh.groups[i]
            bgfx.set_index_buffer(g.ib)
            bgfx.set_vertex_buffer(g.vb)
            bgfx.submit(0, ctx.prog, 0, i ~= num)
        end
    end
end

return render_mesh