local utils         = require "common.utils"
local class         = utils.class
local base_view     = class "BaseView"
local camera_view   = class("CameraView",   base_view)
local material_view = class("MaterialView", base_view)
local slot_view     = class("SlotView",     base_view)
local collider_view = class("ColliderView", base_view)
local effect_view   = class("EffectView",   base_view)
local light_view    = class("LightView",    base_view)
local skybox_view   = class("SkyboxView",   material_view)

return {
    BaseView    = base_view,
    CameraView  = camera_view,
    MaterialView= material_view,
    LightView   = light_view,
    SlotView    = slot_view,
    ColliderView= collider_view,
    EffectView  = effect_view,
    SkyboxView  = skybox_view,
}