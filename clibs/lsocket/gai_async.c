/* gai_async.c
 * 
 * a simple wrapper for getaddrinfo using pthreads to make it asynchronous.
 *
 * Gunnar Zötl <gz@tset.de>, 2013-2015
 * Released under the terms of the MIT license. See file LICENSE for details.
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include "gai_async.h"
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* handler for asynchronous getaddrinfo() requests. Carries everything
 * getaddrinfo() needs and also some housekeeping stuff like the worker
 * thread id, the run status of the request and the error code returned
 * by getaddrinfo() upon completion.
 */
struct gai_request {
	pthread_t worker;
	int done;
	int err;
	char *node;
	char *service;
	struct addrinfo *hints;
	struct addrinfo *res;
};

/* helper for gai_worker: this cleanup handler marks the request as done
 * when it completed normally and also when it was canceled.
 */
static void gai_cleanup(void *arg)
{
	struct gai_request *rq = (struct gai_request*) arg;
	rq->done = 1;
}

/* gai_worker
 * 
 * perform the getaddrinfo request. Started as a thread by gai_start.
 * 
 * Arguments:
 * 	arg		pointer to a gai_request structure
 * 
 * Returns:
 * 	0, is ignored by the call to pthread_join() in gai_finalize()
 */
static void *gai_worker(void *arg)
{
	struct gai_request *rq = (struct gai_request*) arg;
	pthread_cleanup_push(gai_cleanup, rq);
	rq->err = getaddrinfo(rq->node, rq->service, rq->hints, &rq->res);
	pthread_cleanup_pop(1);
	return 0;
}

/* gai_start
 * 
 * start the getaddrinfo worker thread.
 * 
 * Arguments:
 * 	node	node name, as for getaddrinfo()
 * 	service	service name, as for getaddrinfo()
 * 	hints	criteria for name resolving, as for getaddrinfo()
 * 
 * Returns:
 * 	a pointer to the request handler on success, NULL on failure. If this
 * 	function returns NULL, it is always because the worker thread could
 * 	not be spawned.
 */
struct gai_request *gai_start(const char *node, const char *service, const struct addrinfo *hints)
{
	struct gai_request *rq = malloc(sizeof(struct gai_request));
	if (rq) {
		rq->done = 0;
		rq->node = node ? strdup(node) : NULL;
		rq->service = service ? strdup(service) : NULL;
		if (hints) {
			rq->hints = malloc(sizeof(struct addrinfo));
			memcpy(rq->hints, hints, sizeof(struct addrinfo));
		} else
			rq->hints = NULL;
		rq->res = NULL;
		
		int _err = pthread_create(&rq->worker, NULL, gai_worker, (void*) rq);
		if (_err) {
			free(rq);
			rq = 0;
		}
	}
	return rq;
}

/* gai_poll
 * 
 * check whether the request has finished.
 * 
 * Arguments:
 * 	rq	gai_request to check.
 * 
 * Returns:
 * 	1 if finished, 0 if still running, and EAI_SYSTEM on error. An error
 * 	can only occur if rq is invalid (a.k.a. NULL), in which case errno
 * 	is set to EINVAL
 */
int gai_poll(struct gai_request *rq)
{
	if (rq)
		return rq->done;
	errno = EINVAL;
	return EAI_SYSTEM;
}

/* gai_cancel
 * 
 * cancel a pending getaddrinfo request.
 * 
 * Arguments:
 * 	rq	gai_request to cancel.
 * 
 * Returns:
 * 	0 on success, EAI_SYSTEM on error. Errno will be set accordingly, either
 * 	EINVAL if the rq pointer was NULL, or any error pthread_cancel returned,
 * 	which, according to its manpage, will be ESRCH if there was no active
 * 	thread with the id stored in the rq structure.
 * 
 * Note: you must still call gai_finalize on a canceled request. No guarantee
 * can be made about when the request will be canceled.
 */
int gai_cancel(struct gai_request *rq)
{
	if (rq) {
		int err = pthread_cancel(rq->worker);
		if (err)
			errno = err;
		else
			return 0;
	} else
		errno = EINVAL;
	return EAI_SYSTEM;
}

/* gai_finalize
 * 
 * finalize getaddrinfo request, clean up the gai_request structure and
 * fetch the result from getaddrinfo.
 * 
 * Arguments:
 * 	rq	gai_request to get results from
 * 	res	pointer to pointer for result, like the last argument to getaddrinfo()
 * 
 * Returns:
 * 	0 on success, one of the EAI error codes if the request terminated
 *	successful, but getaddrinfo failed, or EAI_SYSTEM with errno set to
 *	EAGAIN if the request is not yet terminated, or to EINVAL if rq was
 *	NULL. If the request has previously been canceled, errno will be set
 * 	to ECANCELED.
 * 
 * After the call to gai_finalize, the gai_request handler in rq is no
 * longer valid.
 */
int gai_finalize(struct gai_request *rq, struct addrinfo **res)
{
	*res = NULL;
	if (rq) {
		if (rq->done) {
			void *rv;
			pthread_join(rq->worker, &rv);
			int err = rq->err;
			if (rq->node) free(rq->node);
			if (rq->service) free(rq->service);
			if (rq->hints) free(rq->hints);
			*res = rq->res;
			free(rq);
			if (rv == PTHREAD_CANCELED) {
				if (*res) freeaddrinfo(*res);
				errno = ECANCELED;
				*res = NULL;
			} else
				return err;
		} else
			errno = EAGAIN;
	} else {
		errno = EINVAL;
	}
	return EAI_SYSTEM;
}
