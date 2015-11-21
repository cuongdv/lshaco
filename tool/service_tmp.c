#include "shaco.h"
#include "cmdctl.h"
#include <stdlib.h>

struct tmp {
};

struct tmp *
tmp_create() {
    return NULL;
}

void
tmp_free(struct tmp *self) {
}

int
tmp_init(struct shaco_module *s) {
    //struct tmp *self = MODULE_SELF;
    return 0;
}

void
tmp_time(struct shaco_module *s) {
    //struct tmp *self = MODULE_SELF;
}

void
tmp_main(struct shaco_module *s, int session, int source, int type, const void *msg, int sz) {
    //struct tmp *self = MODULE_SELF;
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
