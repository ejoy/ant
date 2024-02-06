#pragma once

#include <cstdint>


#define MAX_VISIBLE_QUEUE   64
struct queue_container;
struct queue_container* queue_create();
void queue_destroy(struct queue_container*);
int queue_alloc(struct queue_container* Q);
int queue_dealloc(struct queue_container* Q, int Qidx);
bool queue_check(struct queue_container* Q, int Qidx, uint8_t queue);
void queue_set(struct queue_container* Q, int Qidx, uint8_t queue, bool value);
void queue_fetch(struct queue_container* Q, int Qidx, uint64_t *outmasks);