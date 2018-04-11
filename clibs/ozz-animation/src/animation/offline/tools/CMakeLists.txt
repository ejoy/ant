add_library(ozz_animation_offline_skel_tools STATIC
  ${PROJECT_SOURCE_DIR}/include/ozz/animation/offline/tools/convert2skel.h
  convert2skel.cc)
target_link_libraries(ozz_animation_offline_skel_tools
  ozz_animation_offline
  ozz_options)
set_target_properties(ozz_animation_offline_skel_tools
  PROPERTIES FOLDER "ozz/tools")

install(TARGETS ozz_animation_offline_skel_tools DESTINATION lib)

fuse_target("ozz_animation_offline_skel_tools")

add_library(ozz_animation_offline_anim_tools STATIC
  ${PROJECT_SOURCE_DIR}/include/ozz/animation/offline/tools/convert2anim.h
  convert2anim.cc)
target_link_libraries(ozz_animation_offline_anim_tools
  ozz_animation_offline
  ozz_options)
set_target_properties(ozz_animation_offline_anim_tools
  PROPERTIES FOLDER "ozz/tools")

install(TARGETS ozz_animation_offline_anim_tools DESTINATION lib)

fuse_target("ozz_animation_offline_anim_tools")
