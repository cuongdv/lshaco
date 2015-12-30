local shaco = require "shaco"
local signal = require "signal.c"

shaco.start(function()
    print(signal.signal(signal.SIGUSR1, function(sig)
        print('recv sigusr1')
    end))
    local n=0
    local f = signal.signal(signal.SIGUSR1, function(sig)
        n = n+1
        print('recv sigusr1 '..n)
    end)
    print(f)
    f()

    local f = signal.signal(signal.SIGINT, function()
        print('recv sigint')
    end)
    print (f)
    f()
    print ('reinstall----------------')
    print(signal.signal(signal.SIGINT, f))
    for i=1, 10 do
        signal.raise(signal.SIGUSR1)
    end

    print(signal.signal(signal.SIGCHLD, function(sig, pid, reason, code, extra)
        print ('---------recv chld', sig, pid, reason, code, extra)
    end))

    for i=1, 10 do
        signal.raise(signal.SIGCHLD);
    end
end)
