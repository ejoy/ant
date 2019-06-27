local define = {}

define.DefaultOpen = {
    defaultValue = false,
    type = "boolean",
}

define.DisplayName = {
    defaultValue = "",
    type = "string",
}

define.ArrayStyle = {
    defaultValue = 1,
    type = "enum",
    enumValue = {"index","group"},
}

return define