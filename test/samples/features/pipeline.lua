local ecs = ...
local pipeline = ecs.pipeline

pipeline "init" {
    "init",
    "init_blit_render",
    "post_init",
}

pipeline "exit" {
    "exit",
}

pipeline "update" {
    "start",
    "timer",
    "data_changed",
    "scene_update",
    pipeline "collider" {
        "update_collider_transform",
        "update_collider",
    },
    pipeline "animation" {
        "animation_state",
        "sample_animation_pose",
        "do_ik",
        "skin_mesh",
        "end_animation",
    },
    pipeline "sky" {
        "update_sun",
        "update_sky",
    },
    "widget",
    pipeline "render" {
        "shadow_camera",
        "load_render_properties",
        "filter_primitive",
        "make_shadow",
        "debug_shadow",
        "cull",
        "render_commit",
        pipeline "postprocess" {
            "bloom",
            "tonemapping",
            "combine_postprocess",
        }
    },
    "camera_control",
    "lock_target",
    "pickup",
    "after_pickup",
	"editor_update",
    "update_editable_hierarchy",
    pipeline "ui" {
        "ui_start",
        "ui_update",
        "ui_end",
    },
    "end_frame",
    "after_update",
    "final",
}
