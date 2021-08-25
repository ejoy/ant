local ecs = ...
local world = ecs.world
local w = world.w

local raster_sys = ecs.system "raster_system"


function raster_sys:end_filter()
    for e in w:select "filter_result:in render_object:in filter_material:out" do
        local fr = e.filter_result
        local le = w:singleton("bake_lightmap_queue", "primitive_filter:in")
        for _, fn in ipairs(le.primitive_filter) do
            if fr[fn] then
                local fm = e.filter_material
                local ro = e.render_object
                local nm = load_bake_material(ro)
                fm[fn] = {
                    fx          = nm.fx,
                    properties  = nm.properties,
                    state       = to_none_cull_state(nm.state),
                    stencil     = nm.stencil,
                }
            end
        end
    end
end