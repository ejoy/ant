#pragma once

#include <stdint.h>

typedef struct {
	uint32_t state[5];
	uint32_t count[2];
	uint8_t  buffer[64];
} SHA1_CTX;
 
#define SHA1_DIGEST_SIZE 20

void sat_SHA1_Init(SHA1_CTX* context);
void sat_SHA1_Update(SHA1_CTX* context,	const uint8_t* data, const size_t len);
void sat_SHA1_Final(SHA1_CTX* context, uint8_t digest[SHA1_DIGEST_SIZE]);
