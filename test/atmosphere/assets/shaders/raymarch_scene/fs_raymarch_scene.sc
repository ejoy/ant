$input v_viewray
#include <bgfx_shader.sh>

#include "common/camera.sh"

static const vec3 kSphereCenter = vec3(0.0, 0.0, 0.0);
static const float kSphereRadius = 2.0;

struct intersect_info{
  vec3 pos, normal;
};

float ray_sphere_intersect(vec3 origin, vec3 dir, vec3 sphere_origin, float sphere_radius, out intersect_info ii)
{
  vec3 oo = origin - sphere_origin;
  float oo_dot_dir = dot(oo, dir);
  float oo_dot_oo = dot(oo, oo);
  float ray_sphere_center_squared_distance = oo_dot_oo - oo_dot_dir * oo_dot_dir;
  const float dis = -oo_dot_dir - sqrt(
      sphere_radius * sphere_radius - ray_sphere_center_squared_distance);

  ii.pos = origin + dir * dis;
  ii.normal = normalize(ii.pos - sphere_origin);
  return dis;
}

void main() {
  vec3 view_direction = normalize(v_viewray);

  intersect_info ii;
  const float distance_to_intersection = ray_sphere_intersect(u_eyepos, view_direction, kSphereCenter, kSphereRadius, ii);
  if (distance_to_intersection > 0.0) {
    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
  } else {
    gl_FragColor = vec4(0.8, 0.8, 0.8, 1.0);
  }
}