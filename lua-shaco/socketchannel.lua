local shaco = require "shaco"
local socket = require "socket"
local error = error
local corunning = coroutine.running
local tinsert = table.insert
local tremove = table.remove

local socketchannel = {}
socketchannel.__index = socketchannel

local function close(self)
    if self._id then
        socket.close(self._id)
        self._id = false
    end
end

local function wakeup_all(self, err)
    self._error = err
    for i=1, #self._response_func do
        self._response_func[i] = nil
    end
    for i=1, #self._response_co do
        local co = self._response_co[i]
        self._response_co[i] = nil
        shaco.wakeup(co)
    end
end

local function pop_response(self)
    return tremove(self._response_func, 1), 
           tremove(self._response_co, 1)
end

local function dispatch(self)
    while self._id do
        local func, co = pop_response(self)
        if func then
            local ok, data, err = pcall(func, self._id)
            if ok then
                if data then
                    self._result_data[co] = data
                    shaco.wakeup(co)
                else
                    close(self)
                    shaco.wakeup(co)
                    wakeup_all(self, err or "return error")
                end
            else
                close(self)
                shaco.wakeup(co)
                wakeup_all(self, data or "raise error")
            end
        else
            local ok, err = socket.block(self._id)
            if not ok then
                close(self)
                error(err)
            end
        end
    end
end

local function connect(self)
    if self._id then
        return true
    end
    local co = corunning()
    if #self._connecting > 0 then
        tinsert(self._connecting, co)
        shaco.wait()
        return true
    else
        self._error = nil
        self._connecting[1] = co
        local id, err = socket.connect(self._host, self._port)
        self._connecting[1] = nil
        local ok
        if id then
            socket.readon(id)
            if self._auth then
                ok, err = pcall(self._auth, id)
                if not ok then
                    socket.close(id)
                end
            else
                ok = true
            end
        else
            ok = false
        end
        for i=2, #self._connecting do
            local co = self._connecting[i]
            shaco.wakeup(co)
            self._connecting[i] = nil
        end
        if ok then
            self._id = id 
            shaco.fork(dispatch, self)
            return true
        else
            error(err)
        end
    end
end

function socketchannel.create(opts) 
    local host = opts.host
    local port = opts.port
    if not port then
        host, port = string.match(host, "([^:]+):?(%d+)$")
        port = tonumber(port)
    end
    local self = setmetatable({
        _host = host,
        _port = port,
        _id = false,
        _auth = opts.auth,
        _connecting = {},
        _response_func = {},
        _response_co = {},
        _result_data = {},
        _error = false,
    }, socketchannel)
    return self
end

function socketchannel:connect()
    connect(self)
end

function socketchannel:close()
    close(self)
end

function socketchannel:request(req, response)
    if not connect(self) then
        return
    end
    local ok, err = socket.send(self._id, req)
    if not ok then
        close(self)
        wakeup_all(self, err)
        error(err)
    end

    local co = corunning()
    tinsert(self._response_func, response)
    tinsert(self._response_co, co)

    shaco.wait()

    if self._error then
        error(self._error)
    else
        local r = self._result_data[co]
        self._result_data[co] = nil
        return r 
    end
end

return socketchannel
