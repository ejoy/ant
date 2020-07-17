return {
    name = "ant.tools.prefab_editor",
    ecs = {
        import = {
            "@ant.tools.prefab_editor",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.tools.prefab_editor|init_system",
            "ant.tools.prefab_editor|gizmo_system",
            "ant.tools.prefab_editor|input_system",
            "ant.tools.prefab_editor|camera_system",
            "ant.tools.prefab_editor|gui_system",
            "ant.objcontroller|pickup_system"
        }
    }
}
