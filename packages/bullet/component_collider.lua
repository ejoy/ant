local ecs = ...
local world = ecs.world
local schema = world.schema

schema:type "terrain_collider_info"
    .type "string" ("terrain")

schema:type "terrain_collider"
    .info "terrain_collider_info"

------
-- combine all collider component into one componet
-- so user could query it by only one name "collider"
schema:type "collider_info"
    .type "string" ("box")
    .center "int[3]" {0,0,0}
    .sx "int" (1)
    .sy "int" (1)
    .sz "int" (1)

schema:type "collider"
    .info "collider_info"

local collider = ecs.component_v2 "collider"

-- install delete function here for release
function collider:delete()
    local Physics = world.args.Physics     -- if use message notify, decoupling will be better?
    if Physics then
        Physics:delete_object( self.info.obj,self.info.shape)
    end 
    -- or use message notify mechanism
    print("delete collider",self.info.type)
end
