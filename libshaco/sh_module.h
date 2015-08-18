#ifndef __sh_module_h__
#define __sh_module_h__

#include <stdint.h>
#include <stdbool.h>

struct module;
struct socket_event;

struct dlmodule {
    char *name;
    void *content;
    void *handle;
    void *main_ud;
    void *(*create)();
    void  (*free)(void* pointer);
    int   (*init)(struct module* s, const char *args);
    void  (*send)(struct module *s, 
                  int session, 
                  int source, 
                  int dest, 
                  int type, 
                  const void *msg, 
                  int sz);
    void  (*main)(struct module *s, 
                  int session, 
                  int source, 
                  int type, 
                  const void *msg, 
                  int sz);
};

#define MODULE_INVALID -1
#define MODULE_SELF ((s)->dl.content)
#define MODULE_NAME ((s)->rname)
#define MODULE_ID ((s)->moduleid)

struct module {
    int moduleid; // >= 0, will not change since loaded
    bool inited;
    char *mname;
    char *rname;
    struct dlmodule dl;
};

int module_new(const char *soname, const char *mname, const char *rname, const char *args);
int module_load(const char* name, const char *mod);
int module_init(const char* name);
int module_reload(const char* name);
int module_reload_byid(int moduleid);
int module_query_id(const char* name);
const char* module_query_module_name(int moduleid);

int module_next(int idx);
int module_main(int moduleid, int session, int source, int type, const void *msg, int sz);
int module_send(int moduleid, int session, int source, int dest, int type, const void *msg, int sz);

#endif
