local shaco = require "shaco"
local socket = require "socket"
local table = table
local coroutine = coroutine
local tbl = require "tbl"

local socketchannel = {}
socketchannel.__index = socketchannel

local function close(self)
    if self.__id then
        socket.close(self.__id)
        self.__id = false
    end
end

local function wakeup_all(self, err)
    self.__error = err
    for i=1, #self.__response_func do
        self.__response_func[i] = nil
    end
    for i=1, #self.__response_co do
        local co = self.__response_co[i]
        self.__response_co[i] = nil
        shaco.wakeup(co)
    end
end

local function pop_response(self)
    return table.remove(self.__response_func, 1), 
           table.remove(self.__response_co, 1)
end

local function dispatch(self)
    socket.bind(self.__id, coroutine.running())
    while self.__id do
        local func, co = pop_response(self)
        if func then
            local ok, data, err = pcall(func, self.__id)
            if ok then
                if data then
                    self.__result_data[co] = data
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
            local ok, err = socket.block(self.__id)
            if not ok then
                close(self)
                error(err)
            end
        end
    end
end

local function connect(self)
    if self.__id then
        return true
    end
    local co = coroutine.running()
    if #self.__connecting > 0 then
        table.insert(self.__connecting, co)
        coroutine.yield() 
        return true
    else
        self.__error = nil
        self.__connecting[1] = co
        local id, err = socket.connect(self.__host, self.__port)
        self.__connecting[1] = nil
        local ok
        if id then
            socket.readenable(id, true)
            if self.__auth then
                ok, err = pcall(self.__auth, id)
                if not ok then
                    socket.close(id)
                end
            else
                ok = true
            end
        else
            ok = false
        end
        for i=2, #self.__connecting do
            local co = self.__connecting[i]
            shaco.wakeup(co)
            self.__connecting[i] = nil
        end
        if ok then
            self.__id = id 
            shaco.fork(dispatch, self)
            return true
        else
            error(err)
        end
    end
end

function socketchannel.create(opts) 
    local self = setmetatable({
        __host = assert(opts.host),
        __port = assert(opts.port),
        __id = false,
        __auth = opts.auth,
        __connecting = {},
        __response_func = {},
        __response_co = {},
        __result_data = {},
        __error = false,
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
    local ok, err = socket.send(self.__id, req)
    if not ok then
        close(self)
        wakeup_all(self, err)
        error(err)
    end

    local co = coroutine.running()
    table.insert(self.__response_func, response)
    table.insert(self.__response_co, co)

    coroutine.yield()

    if self.__error then
        error(self.__error)
    else
        return self.__result_data[co]
    end
end

return socketchannel
