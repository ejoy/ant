local ecs = ...

ecs.component_alias("name", "string", "")

local np = ecs.policy "name"
np.require_component "name"