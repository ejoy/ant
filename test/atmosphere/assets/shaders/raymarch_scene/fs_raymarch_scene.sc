$input v_viewray
#include <bgfx_shader.sh>

#include "common/camera.sh"

static const vec3 kSphereCenter = vec3(0.0, 0.0, 0.0);
static const float kSphereRadius = 2.0;
void main() {
  vec3 view_direction = normalize(v_viewray);

  // Compute the distance between the view ray line and the sphere center,
  // and the distance between the camera and the intersection of the view
  // ray with the sphere (or NaN if there is no intersection).
  vec3 p = u_eyepos - kSphereCenter;
  float p_dot_v = dot(p, view_direction);
  float p_dot_p = dot(p, p);
  float ray_sphere_center_squared_distance = p_dot_p - p_dot_v * p_dot_v;
  float distance_to_intersection = -p_dot_v - sqrt(
      kSphereRadius * kSphereRadius - ray_sphere_center_squared_distance);

  if (distance_to_intersection > 0.0) {
    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
  } else {
    gl_FragColor = vec4(0.8, 0.8, 0.8, 1.0);
  }
}