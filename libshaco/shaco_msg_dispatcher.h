#ifndef __shaco_msg_dispatcher_h__
#define __shaco_msg_dispatcher_h__

void shaco_msg_dispatcher_init();
void shaco_msg_dispatcher_fini();
void shaco_msg_push(int source, int dest, int session, int type, const void *msg, int sz);
void shaco_msg_dispatch();
int shaco_msg_empty();

#endif
