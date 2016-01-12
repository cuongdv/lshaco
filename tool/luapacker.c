#include "luapacker.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <errno.h>

#define LINEMAX 256

static char **
fl_get(const char *input, int *n) {
    int cap = 1;
    char **l = malloc(sizeof(char*)*cap);
    FILE *fp = fopen(input, "r");
    int i;
    for (i=0;;i++) { 
        char *line = malloc(LINEMAX);
        char *ret = fgets(line, LINEMAX, fp);
        if (ret == NULL) {
            free(line);
            break;
        }
        size_t len = strlen(line);
        if (len <= 1) {
            free(line);
            fprintf(stderr, "Invalid line\n");
            return NULL;
        }
        line[len-1]='\0'; // strip '\n'
        if (i>=cap) {
            cap *= 2;
            l = realloc(l, sizeof(char*)*cap);
        }
        l[i] = line;
        fprintf(stderr, "[*]%s\n", line);
    }
    *n = i;
    return l;
}

static void
fl_free(char **l, int n) {
    int i;
    for (i=0;i<n;++i) {
        free(l[i]);
    }
    free(l);
}

static int
_pack(const char *input, const char *output) {
    fprintf(stderr, "[+]%s\n", input);
    int n;
    char **l = fl_get(input, &n);
    if (l==NULL) {
        return 1;
    }
    int r = sp_pack(output, l, n);
    fl_free(l,n);
    if (r) {
        fprintf(stderr, "pack error\n");
        return 1;
    } else {
        fprintf(stderr, "[=]ok\n");
        return 0;
    }
}

static int
_unpack_one(const char *pack, const char *name) {
    fprintf(stderr, "[+]%s\n",pack);
    char *dec, *body;
    size_t size;
    body = sp_unpack(pack, name, &dec, &size);
    if (body == NULL) {
        fprintf(stderr, "decrypt error\n");
        return 1;
    }
    FILE *fp = fopen(name, "w");
    if (fp == NULL) {
        fprintf(stderr, "%s", strerror(errno));
        return 1;
    }
    fwrite(dec, size, 1, fp);
    fclose(fp);
    free(body);
    fprintf(stderr, "[=]%s\n",name);
    return 0;
}

static int
_unpack(const char *pack) {
    fprintf(stderr, "[+]%s\n",pack);
    FILE *fp = fopen(pack, "r");
    if (fp == NULL) {
        fprintf(stderr, "%s\n", strerror(errno));
        return 1;
    }
    struct sp_entryv v;
    sp_entryv_init(&v);
    if (sp_lentryv(fp, &v)) {
        fclose(fp);
        return 1;
    }
    fprintf(stderr, "[*]nentry:%d\n", v.c);
    int i;
    for (i=0;i<v.c;++i) {
        struct sp_entry *e = &v.v[i];
        fprintf(stderr, "[=]%s[%d:%d]", 
                e->name, (int)e->offset, (int)e->bodysz);
        if (e->bodysz == 0) {
            fprintf(stderr, "bodysz==0\n");
            continue;
        }
        FILE *cf = fopen(e->name,"w");
        if (cf == NULL) {
            fprintf(stderr, "%s\n", strerror(errno));
            continue;
        }
        char *body = malloc(e->bodysz);
        fread(body, e->bodysz, 1, fp);
        size_t size;
        char *dec = sp_decrypt(body, e->bodysz, &size);
        if (dec == NULL) {
            fprintf(stderr, "decrypt error\n");
            continue;
        }
        fwrite(dec, size, 1, cf);
        free(body);
        fclose(cf);
        fprintf(stderr, "\n");
    }
    sp_entryv_fini(&v);
    fclose(fp);
    return 0;
}

static int
usage(char *argv[]) {
    static const char *USAGE = "\
usage: %s\n\t\
pack outfile sourcelist or\n\t\
unpack infile [output file]\n";
    fprintf(stderr, USAGE, argv[0]);
    exit(1);
}

int 
main(int argc, char *argv[]) {
    if (argc < 2) {
        usage(argv);
    }
    srand(time(NULL));
    if (!strcmp(argv[1], "pack")) {
        if (argc>=4) {
            return _pack(argv[3], argv[2]);
        }
        
    } else if (!strcmp(argv[1], "unpack")) {
        if (argc==3) {
            return _unpack(argv[2]);
        } else if (argc>3) {
            return _unpack_one(argv[2],argv[3]);
        }
    } else {
        usage(argv);
    }
    usage(argv);
    return 0;
}
