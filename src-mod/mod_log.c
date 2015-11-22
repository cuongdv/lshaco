#include "shaco.h"
#include "elog_include.h"
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

struct log {
    struct elog* el;
};

struct log*
log_create() {
    struct log* self = shaco_malloc(sizeof(*self));
    memset(self, 0, sizeof(*self));
    return self;
}

void
log_free(struct log* self) {
    if (self->el) {
        elog_free(self->el);
        self->el = NULL;
    }
    shaco_free(self);
}

int
log_init(struct shaco_module* s) {
    struct log* self = MODULE_SELF;
    
    struct elog* el;
    if (sh_getint("daemon", 0)) { 
        const char* logdir = sh_getstr("logdir", "");
        if (logdir[0] == '\0') {
            fprintf(stderr, "no specify log dir\n");
            return 1;
        }
        if (mkdir(logdir, 0744)) {
            if (errno != EEXIST) {
                fprintf(stderr, "madir `%s` for log fail: %s", logdir, strerror(errno));
                return 1;
            }
        }
        char logfile[PATH_MAX];
        snprintf(logfile, sizeof(logfile), "%s/%d.log",
                logdir,
                sh_getint("id", 0));

        el = elog_create(logfile);
        if (el == NULL) {
            return 1;
        }
        if (elog_set_appender(el, &g_elog_appender_rollfile, "a+")) {
            fprintf(stderr, "elog set appender fail\n");
            return 1;
        }
        struct elog_rollfile_conf conf;
        conf.file_max_num = 10;
        conf.file_max_size = 1024*1024*1024;
        elog_appender_rollfile_config(el, &conf);
    } else {
        el = elog_create("");
        if (el == NULL) {
            return 1;
        }
        if (elog_set_appender(el, &g_elog_appender_file, "a+")) {
            fprintf(stderr, "elog set appender fail\n");
            return 1;
        }
    }

    self->el = el;
    
    char msg[128];
    snprintf(msg, sizeof(msg), ">>> shaco(%d) sh log level %s\n", 
            sh_getint("id", 0), sh_getstr("loglevel", ""));
    elog_append(self->el, msg, strlen(msg));
    return 0;
}

void
log_main(struct shaco_module* s, int session, int source, int type, const void *msg, int sz) {
    struct log* self = MODULE_SELF;
    if (type == SHACO_TLOG) {
        elog_append(self->el, msg, sz);
    } else {
        char tmp[64];
        int n = sh_snprintf(tmp, sizeof(tmp), "[ERROR] recv invalid type %d\n", type);
        elog_append(self->el, tmp, n);
    }
}
