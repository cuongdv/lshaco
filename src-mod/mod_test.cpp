extern "C" {
#include "sh.h"
#include "cmdctl.h"
#include <stdlib.h>
#include "msg.h"
#include "msg_server.h"
#include "msg_client.h"
}


struct test {
};

extern "C" {

struct test *
test_create() {
    return NULL;
}

void
test_free(struct test *self) {
}

int
test_init(struct shaco_module *s) {
    //struct test *self = (struct test*)MODULE_SELF;
    sh_error("%d", 1);
    return 0;
}

void
test_main(struct shaco_module *s, int session, int source, int type, const void *msg, int sz) {
    //struct test *self = MODULE_SELF;
    switch (type) {
    case SHACO_TUM: {
        UM_CAST(UM_BASE, base, msg);
        switch (base->msgid) {
        }
        break;
        }
    case SHACO_TCMD:
        cmdctl(s, source, msg, sz, NULL);
        break;
    }

}

}