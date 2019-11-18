
local Evt       ={
    --Scene&Entity
    HierarchyChange         = "Editor_HierarchyChange",
    EntityInfo              = "Editor_EntityInfo", --type       ="pick" or "editor","auto"
    EntityPick              = "Editor_EntityPick",
    WatchEntity             = "Editor_WatchEntity",
    ModifyComponent         = "Editor_ModifyComponent",
    ResponseWorldInfo       = "Editor_ResponseWorldInfo",
    RequestWorldInfo        = "Editor_RequestWorldInfo",
    RequestHierarchy        = "RequestHierarchy",
    EntityOperate           = "Editor_EntityOperate",
    --Delete,{eid,...}
    GizmoType               = "Editor_GizmoType",--"position"/"rotation"/"scale"
    SystemProfile           = "Editor_SystemProfile",

    --tool
    RunScript               = "Editor_RunScript",

    --between editor
    InspectRes              = "Editor_InspectRes", -- (pkg_path_str)
    OpenRes                 = "Editor_OpenRes",
    OpenScene               = "Editor_OpenScene", -- (pkg_path_str)
    OpenProject             = "Editor_OpenProject", -- ()
    CloseProject            = "Editor_CloseProject", -- ()
    RequestAddPackageToProject  = "Editor_RequestAddPackageToProject",
    ProjectModified         = "Editor_ProjectModified",
}
return Evt