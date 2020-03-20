return {
    name = "ant.test.animation",
    world = {
        policy = {
            "ant.animation|animation",
            "ant.animation|animation_controller.birth",
            "ant.animation|ozzmesh",
            "ant.animation|ozz_skinning",
            "ant.animation|skinning",
            "ant.serialize|serialize",
            "ant.render|mesh",
            "ant.render|render",
            "ant.render|name",
            "ant.render|light.directional",
            "ant.render|light.ambient",
        },
        system = {
            "ant.test.animation|init_loader",
        }
    }
}
