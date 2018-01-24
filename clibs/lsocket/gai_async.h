/* gai_async.h
 * 
 * a simple wrapper for getaddrinfo using pthreads to make it asynchronous.
 *
 * Gunnar Zötl <gz@tset.de>, 2013-2015
 * Released under the terms of the MIT license. See file LICENSE for details.
 * 
 * Usage:
 * 
 * Start request with gai_start(), for arguments see the manpage for
 * getaddrinfo(). Call gai_poll() repeatedly on the gai_request handler
 * returned by gai_start() until it returns 1, then call gai_finalize()
 * to get the result and clean up the handler.
 * 
 * Like so:
 * -----------------------------------------------------------
	char *node = "some.host.name";
	char *service = NULL;
	struct addrinfo hint, *res;
	
	memset(&hint, 0, sizeof(hint));
	hint.ai_family = AF_UNSPEC;
	
	struct gai_request *rq = gai_start(node, service, &hint);
	
	while (gai_poll(rq) == 0) {
		puts("gai_poll() returned 0");
	}
	
	int err = gai_finalize(rq, &res);
 * -----------------------------------------------------------
 * results of the getaddrinfo request are now available in res, and must
 * be free()d using freeaddrinfo()
 */

/* handler structure for asynchronous getaddrinfo() requests.
 */
struct gai_request;

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
struct gai_request *gai_start(const char *node, const char *service, const struct addrinfo *hints);

/* gai_poll
 * 
 * check whether the request has finished.
 * 
 * Arguments:
 * 	rq	gai_request to check.
 * 
 * Returns:
 * 	1 if finished, 0 if still running, and -1 on error. An error can only
 * 	occur if rq is invalid, in which case errno is set to EINVAL
 */
int gai_poll(struct gai_request *rq);

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
int gai_cancel(struct gai_request *rq);

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
int gai_finalize(struct gai_request *rq, struct addrinfo **res);
