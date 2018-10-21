#ifndef SIMPLE_QUEUE_H
#define SIMPLE_QUEUE_H

#define SIMPLE_QUEUE_INITCAP 8
#include "simplelock.h"

#include <stdlib.h>
#include <string.h>

struct simple_queue_slot {
	void *data;
};

struct simple_queue {
	spinlock_t lock;
	int cap;
	int head;
	int tail;
	struct simple_queue_slot *slot;
};


static inline void
simple_queue_init(struct simple_queue *q) {
	memset(q, 0, sizeof(*q));
	spin_lock_init(q);
	q->slot = (struct simple_queue_slot *)malloc(sizeof(struct simple_queue_slot) * SIMPLE_QUEUE_INITCAP);
	q->cap = SIMPLE_QUEUE_INITCAP;
}

static inline void
simple_queue_destroy(struct simple_queue *q) {
	spin_lock_destory(q);
	free(q->slot);
}

static inline void
expand_queue(struct simple_queue *q) {
	struct simple_queue_slot *new_slots = (struct simple_queue_slot *)malloc(sizeof(struct simple_queue_slot) * q->cap * 2);
	int i;
	for (i=0;i<q->cap;i++) {
		new_slots[i] = q->slot[(q->head + i) % q->cap];
	}
	q->head = 0;
	q->tail = q->cap;
	q->cap *= 2;
	
	free(q->slot);
	q->slot = new_slots;
}

static inline void
simple_queue_push(struct simple_queue *q, struct simple_queue_slot *data) {
	spin_lock(q);
	q->slot[q->tail] = *data;
	if (++ q->tail >= q->cap) {
		q->tail = 0;
	}

	if (q->head == q->tail) {
		expand_queue(q);
	}

	spin_unlock(q);
}

static inline int
simple_queue_pop(struct simple_queue *q, struct simple_queue_slot *result) {
	spin_lock(q);
	int empty = (q->head == q->tail);
	if (!empty) {
		*result = q->slot[q->head++];

		if (q->head >= q->cap) {
			q->head = 0;
		}
	}
	
	spin_unlock(q);

	return empty;
}

#endif
