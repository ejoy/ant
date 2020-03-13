--publish from Runtime, subscribe by Editor
local RTE = {}
RTE.HierarchyChange         = "RTE.HierarchyChange"
RTE.EntityInfo              = "RTE.EntityInfo" --type ="pick" or "editor","auto"
RTE.SceneEntityPick         = "RTE.SceneEntityPick"
RTE.ResponseWorldInfo       = "RTE.ResponseWorldInfo"
RTE.SendEntityPolicy        = "RTE.SendEntityPolicy"
RTE.SystemProfile           = "RTE.SystemProfile"
--(reason("editor"/""),eids)
RTE.ResponseNewEntity       = "RTE.ResponseNewEntity"

--publish from Editor, subscribe by Runtime
local ETR = {}
ETR.WatchEntity             = "ETR.WatchEntity"
ETR.ModifyComponent         = "ETR.ModifyComponent"
ETR.ModifyMultComponent     = "ETR.ModifyMultComponent"
ETR.RequestWorldInfo        = "ETR.RequestWorldInfo"
ETR.RequestHierarchy        = "ETR.RequestHierarchy"
ETR.EntityOperate           = "ETR.EntityOperate"
ETR.RequestEntityPolicy     = "ETR.RequestEntityPolicy"
ETR.RequestAddPolicy        = "ETR.RequestAddPolicy"
--("position"/"rotation"/"scale")
ETR.GizmoType               = "ETR.GizmoType"
ETR.RunScript               = "ETR.RunScript"
--({parent=,policy=,data=,str=})
ETR.NewEntity               = "ETR.NewEntity"
--( eids )
ETR.DuplicateEntity         = "ETR.NewEntity"

--publish from Editor, subscribe by Editor
local ETE = {}
ETE.InspectRes              = "ETE.InspectRes" -- (pkg_path_str)
ETE.OpenRes                 = "ETE.OpenRes"
ETE.OpenScene               = "ETE.OpenScene" -- (pkg_path_str)
ETE.OpenProject             = "ETE.OpenProject" -- ()
ETE.CloseProject            = "ETE.CloseProject" -- ()
ETE.RequestAddPackageToProject  = "ETE.RequestAddPackageToProject"
ETE.ProjectModified         = "ETE.ProjectModified"
ETE.OpenAddPolicyView       = "ETE.OpenAddPolicyView"

return {
    RTE = RTE,
    ETR = ETR,
    ETE = ETE,
}