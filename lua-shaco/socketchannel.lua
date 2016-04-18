local shaco = require "shaco"
local socket = require "socket"
local socket_error = socket.error
local corunning = coroutine.running
local tinsert = table.insert
local tremove = table.remove

local socketchannel = {}
socketchannel.__index = socketchannel

local function close_channel(self)
    if self.__id then
        socket.close(self.__id)
        self.__id = false
        self.__open = false
    end
end

local function wakeup_all(self, err)
    for i=1, #self.__response_func do
        self.__response_func[i] = nil
    end
    for i=1, #self.__response_co do
        local co = self.__response_co[i]
        self.__response_co[i] = nil
        self.__result[co] = false
        self.__result_data[co] = err
        shaco.wakeup(co)
    end
end

local function pop_response(self)
    return tremove(self.__response_func, 1), 
           tremove(self.__response_co, 1)
end

local function dispatch(self)
    while self.__id do
        local func, co = pop_response(self)
        if func then
            local ok, result_ok, result_data = pcall(func, self)
            if ok then
                self.__result[co] = result_ok
                self.__result_data[co] = result_data
                shaco.wakeup(co)
            else
                close_channel(self)
                self.__result[co] = false
                self.__result_data[co] = result_ok
                shaco.wakeup(co)
                wakeup_all(self, result_ok)
            end
        else
            local ok = socket.block(self.__id)
            if not ok then
                close_channel(self)
                wakeup_all(self, socket_error)
            end
        end
    end
end

local function connect(self)
    if self.__open then
        return true
    else
        if self.__auth_co == coroutine.running() then
            return true -- authing
        end
    end
    local co = corunning()
    if #self.__connecting > 0 then
        tinsert(self.__connecting, co)
        shaco.wait()
        return true
    else
        if self.__reconn_times == 0 then
            return nil, 'No reconnect times' 
        elseif self.__reconn_times > 0 then
            self.__reconn_times = self.__reconn_times - 1
        end
        self.__connecting[1] = co
        local id, err = socket.connect(self.__host, self.__port)
        local ok
        if id then
            self.__id = id
            socket.readon(id)
            shaco.fork(dispatch, self)
            if self.__auth then
                self.__auth_co = coroutine.running()
                ok, err = pcall(self.__auth, self)
                if not ok then
                    socket.close(id)
                    self.__id = false
                end
                self.__auth_co = false
            else
                ok = true
            end
        else
            ok = false
        end
        self.__connecting[1] = nil
        for i=2, #self.__connecting do
            local co = self.__connecting[i]
            shaco.wakeup(co)
            self.__connecting[i] = nil
        end
        if ok then
            self.__open = true
            return true
        else
            return nil, err 
        end
    end
end

function socketchannel.create(opts) 
    local id, host, port
    id = opts.id
    if id then
        assert(type(id)=='number', 'Invalid id')
    else
        host = opts.host
        port = opts.port
        if not port then
            host, port = string.match(host, "([^:]+):?(%d+)$")
            port = tonumber(port)
        end
    end
    local self = setmetatable({
        __host = host,
        __port = port,
        __id = id or false,
        __auth = opts.auth,
        __auth_co = false,
        __connecting = {},
        __response_func = {},
        __response_co = {},
        __result = {},
        __result_data = {},
        __reconn_times = opts.reconn_times or -1, -- -1 for always reconnect
    }, socketchannel)
    if self.__id then
        self.__reconn_times = 0
        shaco.fork(dispatch, self)
    end
    return self
end

function socketchannel:connect()
    return connect(self)
end

function socketchannel:close()
    close_channel(self)
end

local function wait_response(self, response)
    local co = corunning()
    tinsert(self.__response_func, response)
    tinsert(self.__response_co, co)
    
    shaco.wait()

    local ok = self.__result[co]
    local data = self.__result_data[co]
    self.__result[co] = nil
    self.__result_data[co] = nil
    if not ok then
        error(data)
    end
    return data
end

function socketchannel:request(req, response)
    assert(connect(self))
    local ok, err
    if type(req) == 'function' then
        ok, err = pcall(req, self.__id)
    else
        ok, err = socket.send(self.__id, req)
    end
    if not ok then
        close_channel(self)
        wakeup_all(self, err or socket_error)
        return error(err)
    end
    
    if response == nil then
        return
    end
    return wait_response(self, response)
end

function socketchannel:response(response)
    assert(connect(self))
    return wait_response(self, response)
end

local function wrap_socket_function(f)
    return function(self, ...)
        return assert(f(self.__id, ...))
    end
end

socketchannel.read = wrap_socket_function(socket.read)
socketchannel.ipc_read = wrap_socket_function(socket.ipc_read)
socketchannel.ipc_readfd = wrap_socket_function(socket.ipc_readfd)

return socketchannel
