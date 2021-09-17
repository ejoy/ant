return {
    name = "tools.prefab_editor",
    dependencies = {
        "ant.asset",
        "ant.compile_resource",
        "ant.editor",
        "ant.general",
        "ant.geometry",
        "ant.hwi",
        "ant.imgui",
        "ant.math",
        "ant.render",
        "ant.serialize",
        "ant.camera",
    }
    --ecs = {
    --    import = {
    --        "@tools.prefab_editor",
    --    },
    --    pipeline = {
    --        "init",
    --        "update",
    --        "exit",
    --    },
    --    system = {
    --        "tools.prefab_editor|init_system",
    --        "tools.prefab_editor|gizmo_system",
    --        "tools.prefab_editor|input_system",
    --        "tools.prefab_editor|camera_system",
    --        "tools.prefab_editor|gui_system",
    --        "tools.prefab_editor|physic_system",
    --        "tools.prefab_editor|grid_brush_system"
    --    }
    --}
}
