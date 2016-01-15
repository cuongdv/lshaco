#define ASSIGN_SIG(f)  \
    lua_pushinteger(L, f); \
    lua_setfield(L, -2, #f); \
    if (_sig_max <= f) { \
        _sig_max = f+1; \
    }

#ifdef SIGABRT
	ASSIGN_SIG( SIGABRT		);
#endif
#ifdef SIGALRM
	ASSIGN_SIG( SIGALRM		);
#endif
#ifdef SIGBUS
	ASSIGN_SIG( SIGBUS		);
#endif
#ifdef SIGCHLD
	ASSIGN_SIG( SIGCHLD		);
#endif
#ifdef SIGCONT
	ASSIGN_SIG( SIGCONT		);
#endif
#ifdef SIGFPE
	ASSIGN_SIG( SIGFPE		);
#endif
#ifdef SIGHUP
	ASSIGN_SIG( SIGHUP		);
#endif
#ifdef SIGILL
	ASSIGN_SIG( SIGILL		);
#endif
#ifdef SIGINT
	ASSIGN_SIG( SIGINT		);
#endif
#ifdef SIGKILL
	ASSIGN_SIG( SIGKILL		);
#endif
#ifdef SIGPIPE
	ASSIGN_SIG( SIGPIPE		);
#endif
#ifdef SIGQUIT
	ASSIGN_SIG( SIGQUIT		);
#endif
#ifdef SIGSEGV
	ASSIGN_SIG( SIGSEGV		);
#endif
#ifdef SIGSTOP
	ASSIGN_SIG( SIGSTOP		);
#endif
#ifdef SIGTERM
	ASSIGN_SIG( SIGTERM		);
#endif
#ifdef SIGTSTP
	ASSIGN_SIG( SIGTSTP		);
#endif
#ifdef SIGTTIN
	ASSIGN_SIG( SIGTTIN		);
#endif
#ifdef SIGTTOU
	ASSIGN_SIG( SIGTTOU		);
#endif
#ifdef SIGUSR1
	ASSIGN_SIG( SIGUSR1		);
#endif
#ifdef SIGUSR2
	ASSIGN_SIG( SIGUSR2		);
#endif
#ifdef SIGSYS
	ASSIGN_SIG( SIGSYS		);
#endif
#ifdef SIGTRAP
	ASSIGN_SIG( SIGTRAP		);
#endif
#ifdef SIGURG
	ASSIGN_SIG( SIGURG		);
#endif
#ifdef SIGVTALRM
	ASSIGN_SIG( SIGVTALRM	);
#endif
#ifdef SIGXCPU
	ASSIGN_SIG( SIGXCPU		);
#endif
#ifdef SIGXFSZ
	ASSIGN_SIG( SIGXFSZ		);
#endif

#define ASSIGN_FLAG(f) \
    lua_pushinteger(L, f); \
    lua_setfield(L, -2, #f);

#ifdef SA_NOCLDSTOP
	ASSIGN_FLAG( SA_NOCLDSTOP	);
#endif
#ifdef SA_NOCLDWAIT
	ASSIGN_FLAG( SA_NOCLDWAIT	);
#endif
#ifdef SA_RESETHAND
	ASSIGN_FLAG( SA_RESETHAND	);
#endif
#ifdef SA_NODEFER
	ASSIGN_FLAG( SA_NODEFER	);
#endif
