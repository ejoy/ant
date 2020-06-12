return {
    name = "ant.test.prefab_editor",
    ecs = {
        import = {
            "@ant.test.prefab_editor",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.prefab_editor|init_system",
            "ant.test.prefab_editor|geo_system",
            "ant.test.prefab_editor|gizmo_system",
            "ant.test.prefab_editor|input_system",
            "ant.test.prefab_editor|camera_system",
            "ant.objcontroller|pickup_system"
        }
    }
}
