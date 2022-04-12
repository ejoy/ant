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
        "ant.rmlui",
        "ant.math",
        "ant.render",
        "ant.serialize",
        "ant.camera",
        "ant.animation",
        "ant.collision",
        "ant.sky",
        --"ant.effekseer",
        "ant.audio",
        "ant.inputmgr",
        "ant.ecs",
        "ant.subprocess",
        "ant.settings",
        "ant.objcontroller",
        "ant.terrain",
    },
    entry = "editor.callback",
    ecs = {
        import = {
            "@tools.prefab_editor"
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
            "tools.prefab_editor|grid_brush_system",
            "tools.prefab_editor|gui_system",
            "ant.objcontroller|pickup_system",
            "ant.camera|default_camera_controller",
        }
    }
}
