local ecs = ...

ecs.tag = function (name)
    ecs.component_alias(name, "tag")
end
ecs.component_alias("tag", "boolean", true)
ecs.component_base("entityid", -1)

ecs.component_base("int", 0)
ecs.component_base("real", 0.0)
ecs.component_base("string", "")
ecs.component_base("boolean", false)
