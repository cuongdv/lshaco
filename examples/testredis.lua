local shaco = require "shaco"
local redis = require "redis"
local tbl = require "tbl"

local conf = {
    host = "127.0.0.1",
    port = 6379,
    db = 1,
}
shaco.start(function()
    shaco.fork(function()
        local w = redis.watch(conf)
        w:subscribe("ch1")
        w:psubscribe("ch.*")
        while true do
            print('watch:', w:message())
        end
    end)

    local db = redis.connect(conf)
    print("[get]")
    print(db:get('a'))
    print(db:set('a', 100))
    print(db:get('a'))

    print("[move]")
    print(db:move('a', 2))
    print(db:get('a'))
    print(db:select(2))
    print(db:get('a'))
    print(db:smove(2, 1, 'a'))
    print(db:select(1))
    print(db:get('a'))

    print('[exists]')
    print(db:exists('a'))
    print(db:exists('A'))

    print('[sismember]')
    print(db:sismember('S', 'a'))

    print('[hexists]')
    print(db:hexists('H', 'a'))

    print("[list]")
    print(db:del('list_l'))
    print(db:lpush('list_l', 1))
    print(db:lpush('list_l', 2, 3, 4, 5))
    print(tbl(db:lrange('list_l', 0, -1)))
    for i = 1,db:llen('list_l')-1 do
        print(db:rpop('list_l'))
    end
    print(tbl(db:brpop('list_l', 10)))
    db:close()

    print('[multi]')
    print(db:multi())
    print(db:get('a'))
    print(db:get('A'))
    print(db:get('C'))
    local r = db:exec()
    for k, v in pairs(r) do
        print(k, v)
    end

    print('[publish]')
    for i = 1,10 do
        print(db:publish('ch1', i))
    end
    shaco.sleep(5000)
    for i = 1,10 do
        print(db:publish('ch.1', i))
    end
end)
