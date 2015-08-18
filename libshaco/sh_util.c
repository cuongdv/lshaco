#include "sh_util.h"
#include <assert.h>
#include <unistd.h>
#include <sys/wait.h>

int
sh_fork(char *const argv[], int n) {
    assert(n > 0);
    if (argv[n-1] != NULL) {
        return 1;
    }
    pid_t pid = fork();
    if (pid < 0) {
        return 1;
    }
    if (pid == 0) {
        pid_t pid2 = fork();
        if (pid2 < 0) {
            exit(0);
        }
        if (pid2 == 0) {
            execvp(argv[0], argv);
            // !!! do not call exit(1), 
            // exit will call the function register in atexit,
            // this will call net fini, del epoll_ctl event
            // eg: epoll_ctl del event, listen socket disabled!
            _exit(1);
            return 0;
        } else {
            // !!! do not call exit(1)
            _exit(1);
            return 0;
        }
    } else {
        if (waitpid(pid, NULL, 0) != pid)
            return 1;
        return 0;
    }
}
