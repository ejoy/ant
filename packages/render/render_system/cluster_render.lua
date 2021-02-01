local ecs = ...
local world = ecs.world
local cluster_defer_sys = ecs.system "cluster_deferred_system"

--1. build cluster aabb
--2. find visble cluster. [opt]
--3. cull lights
--4. shading

function cluster_defer_sys:render_preprocess()

end

function cluster_defer_sys:render_submit()
    
end