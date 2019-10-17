
shader = {
  fs = "/pkg/ant.resources/shaders/shadow/csm/fs_mesh.sc",
  vs = "/pkg/ant.resources/shaders/shadow/csm/vs_mesh.sc"
}

surface_type = {
  lighting = "on",
  shadow = {
    cast = "on",
    receive = "on"
  },
  subsurface = "off",
  transparency = "opaticy"
}
