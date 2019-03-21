local ecs = ...

ecs.import 'ant.render'
ecs.import 'ant.bullet'
ecs.import 'ant.scene'
ecs.import 'ant.animation'

local ma = ecs.system "math_adapter"
ma.depend 'physic_math_adapter'
ma.depend 'render_math_adapter'
ma.depend 'hierarchy_bind_math'
ma.depend 'animation_math_adapter'