#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <assert.h>
#include <unistd.h>

//static volatile sig_atomic_int g_i;

static void handler(int sig) {
    fprintf(stderr, "1sig %d handler\n", sig);
    fprintf(stderr, "2sig %d handler\n", sig);
    fprintf(stderr, "3sig %d handler\n", sig);
    fprintf(stderr, "4sig %d handler\n", sig);
    fprintf(stderr, "%d---------------------\n", sig);
}

void install(int sig) {
    struct sigaction sa;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sa.sa_handler = handler;
    int ret = sigaction(sig, &sa, NULL);
    assert(ret == 0);
}

int main() {
    fprintf(stderr, "pid=%d\n", getpid());
    install(SIGUSR1);
    install(SIGUSR2);
    while (1) {}
    return 0;
}
