#ifndef __shaco_harbor_h__
#define __shaco_harbor_h__

struct shaco_context;

struct shaco_remote_message {
    int dest;
    int type;
    const void *msg;
    int sz;
};

void shaco_harbor_start(struct shaco_context *ctx);
int  shaco_harbor_isremote(int handle);
void shaco_harbor_send(int dest, int source, int session, int type, const void *msg, int sz);

#endif
