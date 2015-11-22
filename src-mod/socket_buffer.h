#ifndef __socket_buffer_h__
#define __socket_buffer_h__

struct buffer_node;
struct socket_buffer {
    int size;
    int offset;
    int header;
    struct buffer_node *head;
    struct buffer_node *tail;
};

struct socket_pack {
    void *p;
    int sz;
};

void sb_init(struct socket_buffer *sb);
void sb_fini(struct socket_buffer *sb);
void sb_push(struct socket_buffer *sb, void *buf, int sz);
int  sb_pop(struct socket_buffer *s, struct socket_pack *sp);

#endif
