local define = {}

define.DefaultOpen = {
    defaultValue = false,
    type = "boolean",
}

define.DisplayName = {
    defaultValue = "",
    type = "string",
}

define.HideHeader = {
    defaultValue = false,
    type = "boolean",
}

define.ArrayStyle = {
    defaultValue = 1,
    type = "enum",
    enumValue = {"index","group"},
}

define.ArrayAsVector = {
    defaultValue = false,
    type = "boolean",
}

return define