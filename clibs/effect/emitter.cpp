#include "pch.h"
#include "emitter.h"
#include "random.h"
#include "particle_mgr.h"
#include "particle.inl"

static void
check_add_id(comp_ids &ids, component_id id){
	assert(std::find(ids.begin(), ids.end(), id) == ids.end());
	ids.push_back(id);
}

std::unordered_map<component_id, std::function<void (const particle_emitter::spawndata&, randomobj &, comp_ids &)>> g_spwan_operations = {
	std::make_pair(ID_life, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::life(spawn.init.life.get(ro()))
		));
	}),
	std::make_pair(ID_velocity, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::velocity(spawn.init.velocity.get(ro()))
		));
	}),
	std::make_pair(ID_acceleration, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::acceleration(spawn.init.acceleration.get(ro()))
		));
	}),
	std::make_pair(ID_scale, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::scale(spawn.init.scale.get(ro()))
		));
	}),
	std::make_pair(ID_rotation, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		// check_add_id(ids, particle_mgr::get().add_component(
		// 	particles::scale(spawn.init.scale.get(ro()))
		// ));
	}),
	std::make_pair(ID_translation, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::translation(spawn.init.translation.get(ro())
		)));
	}),
	std::make_pair(ID_uv, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		
	}),
	std::make_pair(ID_uv_motion, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::uv_motion(spawn.init.uv_motion.get(ro()))
		));
	}),
	std::make_pair(ID_color, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		particles::color c;
		for(int ii=0; ii<4;++ii){
			c[ii] = to_color_channel(spawn.init.color.rgba[ii].get(ro()));
		}
		check_add_id(ids, particle_mgr::get().add_component(c));
	}),
	std::make_pair(ID_material, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(particles::material(spawn.init.material)));
	}),
	std::make_pair(ID_velocity_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_velocity) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::velocity(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::velocity_interpolator(spawn.interp.velocity)
		));
	}),
	std::make_pair(ID_acceleration_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_acceleration) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::acceleration(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::acceleration_interpolator(spawn.interp.acceleration)
		));
	}),
	std::make_pair(ID_scale_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_scale) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::scale(1.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::scale_interpolator(spawn.interp.scale)
		));
	}),
	std::make_pair(ID_rotation_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		// if (std::find(ids.begin(), ids.end(), ID_rotation) != ids.end()){
		// 	check_add_id(ids, particle_mgr::get().add_component(particles::rotation(0.f)));
		// }
		// check_add_id(ids, particle_mgr::get().add_component(
		// 	particles::rotation_interpolator(spawn.interp.rotation)
		// ));
	}),
	std::make_pair(ID_translation_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_translation) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::translation(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::translation_interpolator(spawn.interp.translation)
		));
	}),
	std::make_pair(ID_uv_motion_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_uv_motion) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::uv_motion(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::uv_motion_interpolator(spawn.interp.uv_motion)
		));
	}),
	std::make_pair(ID_subuv, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::subuv(spawn.init.subuv)
		));
	}),
	std::make_pair(ID_subuv_index_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		assert(std::find(ids.begin(), ids.end(), ID_subuv) != ids.end());
		check_add_id(ids, particle_mgr::get().add_component(
			particles::subuv_index_interpolator(spawn.interp.subuv_index)
		));
	}),
	std::make_pair(ID_color_interpolator, [](const particle_emitter::spawndata& spawn, randomobj &ro, comp_ids &ids){
		assert(std::find(ids.begin(), ids.end(), ID_color) != ids.end());
		check_add_id(ids, particle_mgr::get().add_component(
			particles::color_interpolator(spawn.interp.color)
		));
	}),
};

void
particle_emitter::spawn(const glm::mat4 &transform){
	randomobj ro;

    comp_ids ids;
    ids.push_back(ID_TAG_render_quad);
    for (auto id : mspawn.init.components)
        g_spwan_operations[id](mspawn, ro, ids);
    for (auto id : mspawn.interp.components)
        g_spwan_operations[id](mspawn, ro, ids);

    particle_mgr::get().add(ids);
}