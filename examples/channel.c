#include <sys/socket.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <assert.h>
static inline int
_socket_nonblocking(int fd) {
    int flag = fcntl(fd, F_GETFL, 0);
    if (flag == -1)
        return -1;
    return fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}


static inline int
_sendmsg(int fd, void *data, int size, int cfd) {
    struct iovec iov[1];
    struct msghdr msg;
    if (cfd < 0) {
        msg.msg_control = NULL;
        msg.msg_controllen = 0;
    } else {
        union {
            struct cmsghdr  cm;
            char            space[CMSG_SPACE(sizeof(int))];
        } cmsg;

        msg.msg_control = (caddr_t)&cmsg;
        msg.msg_controllen = sizeof(cmsg);
        memset(&cmsg, 0, sizeof(cmsg));
        cmsg.cm.cmsg_len = CMSG_LEN(sizeof(int));
        cmsg.cm.cmsg_level = SOL_SOCKET;
        cmsg.cm.cmsg_type = SCM_RIGHTS;
        *(int*)CMSG_DATA(&cmsg.cm) = cfd;
    } 
    msg.msg_flags = 0;

    iov[0].iov_base = data;
    iov[0].iov_len = size;

    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    return sendmsg(fd, &msg, 0);
}

static inline void
_send(int fd, void *data, int size, int cfd) {
    int n = _sendmsg(fd, data, size, cfd);
    if (n==-1) {
        fprintf(stderr, "sendmsg error %d:%s\n", errno, strerror(errno));
    } else {
        if (n != size) {
        fprintf(stderr, "sendmsg n!=size, %d!=%d\n", n, size);
        }
    }
}

int
_recvmsg(int fd) {
    union {
        struct cmsghdr  cm;
        char            space[CMSG_SPACE(sizeof(int))];
    } cmsg;

    char tmp[100];
    struct iovec iov[1];
    iov[0].iov_base = tmp;
    iov[0].iov_len = sizeof(tmp);

    struct msghdr msg;
    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;

    msg.msg_control = (caddr_t)&cmsg;
    msg.msg_controllen = sizeof(cmsg);
    memset(&cmsg, 0, sizeof(cmsg));
    int n = recvmsg(fd, &msg, 0);
    if (n<0) {
        fprintf(stderr, "recvmsg error %d: %s\n", errno, strerror(errno));
        return -1;
    } else {
        if (msg.msg_flags & (MSG_TRUNC|MSG_CTRUNC)) {
            fprintf(stderr, "recvmsg trunc\n");
            return -1;
        }
        int cfd;
        if (cmsg.cm.cmsg_len == CMSG_LEN(sizeof(int))) {
            if (cmsg.cm.cmsg_level != SOL_SOCKET || cmsg.cm.cmsg_type != SCM_RIGHTS) {
                fprintf(stderr, "recvmsg recvfd error\n");
                return -1; 
            }
            cfd = *(int*)CMSG_DATA(&cmsg.cm);
        } else {
            cfd = -1;
        }
        fprintf(stderr, "recvmsg n=%d, cmsg_len=%d, cfd=%d\n", n, cmsg.cm.cmsg_len, cfd);
        return 0;
    }
}

void test_send() {
    char buf[3000];
    int i;
    for (i=0;i<sizeof(buf);++i) {
        buf[i] = i;
    }
    int fildes[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, fildes)) {
        fprintf(stderr, "socketpair error:%s\n", strerror(errno));
    }
    int fd = fildes[0];
    _socket_nonblocking(fd);

    for (i=0;i<9; ++i) {
        FILE *fp = fopen("1.txt", "a+");
        assert(fp);
        int filefd = fileno(fp);
        fprintf(stderr, "send %d\n", i);
        _send(fd, buf, sizeof(buf), filefd);
    }
}

int test() {
    int fildes[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, fildes)) {
        fprintf(stderr, "socketpair error:%s\n", strerror(errno));
        return 1;
    }
    {
        int fd = fildes[0];
        _socket_nonblocking(fd);
        FILE *fp = fopen("1.txt", "a+");
        assert(fp);
        int filefd = fileno(fp);
        FILE *fp2 = fopen("2.txt", "a+");
        assert(fp2);
        int filefd2 = fileno(fp2);
        _send(fd, "123", 3, -1);
        _send(fd, "456", 3, filefd);
        _send(fd, "789", 1, -1);
        _send(fd, "123", 3, filefd2);
        _send(fd, "789", 1, -1);
    }
    {
        int fd = fildes[1];
        _socket_nonblocking(fd);
    //    fprintf(stderr, "sleep 3s\n");
    //    sleep(3);
        fprintf(stderr, "start recvmsg\n");
        //char tmp[100];
        //int n = read(fd, tmp, 10);
        //fprintf(stderr, "read n=%d\n", n);
        for(;;) {
            if (_recvmsg(fd) ==-1)
                break;
        }
    }
    //pid_t pid = fork();
    //if (pid < 0) {
    //    close(fildes[0]);
    //    close(fildes[1]);
    //    fprintf(stderr, "fork error:%s\n", strerror(errno));
    //    return 1;
    //} else if (pid == 0) {
    //    close(fildes[0]);
    //    int fd = fildes[1];
    //    _socket_nonblocking(fd);
    //    fprintf(stderr, "sleep 3s\n");
    //    sleep(3000);
    //    fprintf(stderr, "start recvmsg\n");
    //    _recvmsg(fd);
    //    return 0;
    //} else {
    //    close(fildes[1]);
    //    int fd = fildes[0];
    //    _socket_nonblocking(fd);
    //    FILE *fp = fopen("1.txt", "a+");
    //    assert(fp);
    //    int filefd = fileno(fp);
    //    _send(fd, "123", 3, -1);
    //    _send(fd, "456", 3, filefd);
    //    _send(fd, "789", 3, -1);
    //}
    return 0;
}

int main(int argc, char *argv[]) {
    test_send();
    //char buf[1000];
    //int i;
    //for (i=0;i<sizeof(buf);++i) {
    //    buf[i] = i;
    //}
    //int fildes[2];
    //if (socketpair(AF_UNIX, SOCK_STREAM, 0, fildes)) {
    //    fprintf(stderr, "socketpair error:%s\n", strerror(errno));
    //}
    //int fd = fildes[0];
    //_socket_nonblocking(fd);

    //for (i=0;i<9; ++i) {
    //    fprintf(stderr, "send %d\n", i);
    //    _send(fd, buf, sizeof(buf), -1);
    //}

    //pid_t pid = fork();
    //if (pid < 0) {
    //    close(fildes[0]);
    //    close(fildes[1]);
    //    fprintf(stderr, "fork error:%s\n", strerror(errno));
    //    return 1;
    //} else if (pid == 0) {
    //    close(fildes[0]);
    //    sleep(5000);
    //    return 0;
    //} else {
    //    close(fildes[1]);
    //    int fd = fildes[0];
    //    int i;
    //    for (i=0;i<100; ++i) {
    //        _send(fd, buf, sizeof(buf), -1);
    //    }
    //}
    return 0;
}
