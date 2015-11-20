#ifndef __shaco_env_h__
#define __shaco_env_h__

struct lua_State;

void shaco_env_init();
void shaco_env_fini();

const char* shaco_getenv(const char *key);
void shaco_setenv(const char *key, const char *value);

int shaco_optint(const char *key, int def);
float shaco_optfloat(const char *key, float def);
const char *shaco_optstr(const char *key, const char *def);

#endif
