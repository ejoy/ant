
local Evt       ={
    --Scene&Entity
    HierarchyChange         = "Editor_HierarchyChange",
    EntityInfo              = "Editor_EntityInfo", --type       ="pick" or "editor","auto"
    SceneEntityPick         = "Editor_SceneEntityPick",
    WatchEntity             = "Editor_WatchEntity",
    ModifyComponent         = "Editor_ModifyComponent",
    ModifyMultComponent     = "Editor_ModifyMultComponent",
    ResponseWorldInfo       = "Editor_ResponseWorldInfo",
    RequestWorldInfo        = "Editor_RequestWorldInfo",
    RequestHierarchy        = "Editor_RequestHierarchy",
    EntityOperate           = "Editor_EntityOperate",
    RequestEntityPolicy     = "Editor_RequestEntityPolicy",
    SendEntityPolicy        = "Editor_SendEntityPolicy",
    RequestAddPolicy        = "Editor_RequestAddPolicy",
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
    OpenAddPolicyView       = "Editor_OpenAddPolicyView",
}
return Evt