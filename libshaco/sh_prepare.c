#include "sh_init.h"
#include "sh_log.h"
#include "sh_env.h"
#include <stdlib.h>

static void
_prepare() {
    const char* level; 
    level = sh_getstr("loglevel", "");
    sh_log_setlevel(level); 
}

SH_LIBRARY_INIT_PRIO(_prepare, NULL, 1);
