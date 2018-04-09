#ifndef ejoy_intersection_h
#define ejoy_intersection_h

#include "vector3.h"

static inline struct vector3 *
intersection_raytriangle(const struct vector3 *rayOrig, const struct vector3 *rayDir,
	const struct vector3 *vert0, const struct vector3 *vert1, const struct vector3 *vert2,
	struct vector3 *intsPoint) {
	// Idea: Tomas Moeller and Ben Trumbore
	// in Fast, Minimum Storage Ray/Triangle Intersection 
	
	// Find vectors for two edges sharing vert0
	struct vector3 edge1, edge2;
	vector3_vector(&edge1, vert1, vert0);
	vector3_vector(&edge2, vert2, vert0);

	// Begin calculating determinant - also used to calculate U parameter
	struct vector3 pvec;
	vector3_cross(&pvec, rayDir, &edge2);

	// If determinant is near zero, ray lies in plane of triangle
	float det = vector3_dot(&edge1, &pvec);

	// *** Culling branch ***
	/*if( det < FLT_EPSILON )
		return NULL;

	// Calculate distance from vert0 to ray origin
	struct vector3 tvec;
	vector3_vector(&tvec, rayOrig, &vert0);

	// Calculate U parameter and test bounds
	float u = vector3_dot(&tvec, &pvec);
	if (u < 0 || u > det ) 
		return NULL;

	// Prepare to test V parameter
	struct vector3 qvec;
	vector3_cross(&qvec, &tvec, &edge1);

	// Calculate V parameter and test bounds
	float v = vector3_dot(rayDir, &qvec);
	if (v < 0 || u + v > det ) 
		return NULL;

	// Calculate t, scale parameters, ray intersects triangle
	float t = vector3_dot(&edge2, &qvec ) / det;*/

	// *** Non-culling branch ***
	if( det > -FLT_EPSILON && det < FLT_EPSILON )
		return 0;
	float inv_det = 1.0f / det;

	// Calculate distance from vert0 to ray origin
	struct vector3 tvec;
	vector3_vector(&tvec, rayOrig, vert0);

	// Calculate U parameter and test bounds
	float u = vector3_dot(&tvec, &pvec ) * inv_det;
	if( u < 0.0f || u > 1.0f ) 
		return 0;

	// Prepare to test V parameter
	struct vector3 qvec;
	vector3_cross(&qvec, &tvec, &edge1);

	// Calculate V parameter and test bounds
	float v = vector3_dot(rayDir, &qvec ) * inv_det;
	if( v < 0.0f || u + v > 1.0f ) 
		return 0;

	// Calculate t, ray intersects triangle
	float t = vector3_dot(&edge2, &qvec) * inv_det;

	// Calculate intersection point and test ray length and direction
	intsPoint->x = rayOrig->x + rayDir->x * t;
	intsPoint->y = rayOrig->y + rayDir->y * t;
	intsPoint->z = rayOrig->z + rayDir->z * t;

	struct vector3 vec;
	vector3_vector(&vec, intsPoint, rayOrig);
	if( vector3_dot(&vec, rayDir) < 0 || vector3_length(&vec) > vector3_length(rayDir)) 
		return NULL;

	return intsPoint;
}

static inline int
intersection_rayAABB(const struct vector3 *rayOrig, const struct vector3 *rayDir, 
	const struct vector3 *mins, const struct vector3 *maxs ) {
	// SLAB based optimized ray/AABB intersection routine
	// Idea taken from http://ompf.org/ray/
	
	float l1 = (mins->x - rayOrig->x) / rayDir->x;
	float l2 = (maxs->x - rayOrig->x) / rayDir->x;
	float lmin = minf( l1, l2 );
	float lmax = maxf( l1, l2 );

	l1 = (mins->y - rayOrig->y) / rayDir->y;
	l2 = (maxs->y - rayOrig->y) / rayDir->y;
	lmin = maxf( minf( l1, l2 ), lmin );
	lmax = minf( maxf( l1, l2 ), lmax );
		
	l1 = (mins->z - rayOrig->z) / rayDir->z;
	l2 = (maxs->z - rayOrig->z) / rayDir->z;
	lmin = maxf( minf( l1, l2 ), lmin );
	lmax = minf( maxf( l1, l2 ), lmax );

	if( (lmax >= 0.0f) & (lmax >= lmin) ) {
		// Consider length
		const struct vector3 rayDest = { rayOrig->x + rayDir->x , rayOrig->y + rayDir->y , rayOrig->z + rayDir->z };
		const struct vector3 rayMins = { minf( rayDest.x, rayOrig->x), minf( rayDest.y, rayOrig->y ), minf( rayDest.z, rayOrig->z ) };
		const struct vector3 rayMaxs = { maxf( rayDest.x, rayOrig->x), maxf( rayDest.y, rayOrig->y ), maxf( rayDest.z, rayOrig->z ) };
		return 
			(rayMins.x < maxs->x) && (rayMaxs.x > mins->x) &&
			(rayMins.y < maxs->y) && (rayMaxs.y > mins->y) &&
			(rayMins.z < maxs->z) && (rayMaxs.z > mins->z);
	} else {
		return 0;
	}
}

static inline float 
vector3_distAABB(const struct vector3 *pos, const struct vector3 *mins, const struct vector3 *maxs ) {
	struct vector3 center;
	struct vector3 extent;
	center.x = (mins->x + maxs->x) * 0.5f;
	center.y = (mins->y + maxs->y) * 0.5f;
	center.z = (mins->z + maxs->z) * 0.5f;

	extent.x = (maxs->x - mins->x) * 0.5f;
	extent.y = (maxs->y - mins->y) * 0.5f;
	extent.z = (maxs->z - mins->z) * 0.5f;
	
	struct vector3 nearestVec;
	nearestVec.x = maxf( 0, fabsf( pos->x - center.x ) - extent.x );
	nearestVec.y = maxf( 0, fabsf( pos->y - center.y ) - extent.y );
	nearestVec.z = maxf( 0, fabsf( pos->z - center.z ) - extent.z );
	
	return vector3_length(&nearestVec);
}


#endif //ejoy_intersection_h