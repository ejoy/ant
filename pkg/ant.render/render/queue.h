#pragma once

#include <cstdint>

struct queue_container;
struct queue_container* queue_create();
void queue_destroy(struct queue_container*);

bool queue_check(struct queue_container* Q, int Qidx, uint8_t queue);
void queue_set(struct queue_container* Q, int Qidx, uint8_t queue, bool value);