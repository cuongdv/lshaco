
struct command {
    const char *name;
    const char * (*func)(struct shaco_context *ctx, const char *param);
};

struct command C[] = {
    { "QUERY", query },
    { "REG", reg },
    { "CONTEXTNAME", qname },
    { "TIME", time },
    { "STARTTIME", starttime },
    { "GETENV", getenv },
    { "SETENV", setenv },
    { "GETLOGLEVEL", getloglevel },
    { "SETLOGLEVEL", setloglevel },
    { NULL, NULL },
};

const char *
shaco_command(struct shaco_context *ctx, const char *name, const char *param) {
    const struct command *c;
    for (c=C; c->name; c++) {
        if (strcmp(c->name, name)==0)
            return c->func(ctx, param);
    }
    return NULL;
}
