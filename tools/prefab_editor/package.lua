return {
    name = "tools.prefab_editor",
    ecs = {
        import = {
            "@tools.prefab_editor",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "tools.prefab_editor|init_system",
            "tools.prefab_editor|gizmo_system",
            "tools.prefab_editor|input_system",
            "tools.prefab_editor|camera_system",
            "tools.prefab_editor|gui_system",
            "tools.prefab_editor|physic_system"
        }
    }
}
