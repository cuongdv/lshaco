#ifndef __shaco_clusternode_h__
#define __shaco_clusternode_h__

struct shaco_context;

struct shaco_remote_message {
    int dest;
    int type;
    const void *msg;
    int sz;
};

void shaco_clusternode_start(struct shaco_context *ctx);
void shaco_clusternode_send(int dest, int source, int session, int type, const void *msg, int sz);

#endif
