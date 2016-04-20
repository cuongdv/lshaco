local c = require "linenoise.c"
local stdout = io.stdout
local tinsert = table.insert
local tremove = table.remove
local assert = assert
local sbyte = string.byte
local sformat = string.format

local linenoise = {}

local _prompt
local _line
local _cursor_pos
local _historys = {}
local _history_index
local _history_max = 20 --default

local function clear_line()
    _line = ""
    _cursor_pos = 1
    _history_index = #_historys + 1
end

local function refresh()
    local line = '\r'.._prompt.._line..'\x1b[0K\r'
    if _cursor_pos >= 1 then
        line = line..sformat('\x1b[%dC', _cursor_pos-1 + #_prompt)
    end
    stdout:write(line)
    stdout:flush()
end

local function append_char(c)
    _line = 
    _line:sub(1, _cursor_pos-1)..
    c..
    _line:sub(_cursor_pos)
    _cursor_pos = _cursor_pos + 1
end

local function delete_char(pos)
    if pos >= 1 and pos <= #_line then
        _line = 
        _line:sub(1, pos-1)..
        _line:sub(pos+1)
        return true
    end
end

local function move_home()
    if _cursor_pos ~= 1 then
        _cursor_pos = 1
        refresh()
    end
end

local function move_end()
    if _cursor_pos ~= #_line+1 then
        _cursor_pos = #_line+1
        refresh()
    end
end

local function append_history()
    if #_historys > 0 then
        local last = _historys[#_historys]
        if last==_line then 
            return 
        end
        if last=='' then
            tremove(_historys)
        end
    end
    if _line~='' then
        if #_historys >= _history_max then
            tremove(_historys,1)
        end
        _historys[#_historys+1] = _line
    end
end

local function history(index)
    local show = _historys[index]
    _historys[index] = _line
    _line = show
    _cursor_pos = #_line+1
    refresh()
end

local function move_up()
    if _history_index > 1 then
        _history_index = _history_index-1
        history(_history_index)
    end
end

local function move_down()
    if _history_index <= #_historys then
        history(_history_index)
        _history_index = _history_index+1
    end
end

local function move_right()
    if _cursor_pos <= #_line then
        _cursor_pos = _cursor_pos+1
        refresh()
    end
end

local function move_left()
    if _cursor_pos > 1 then
        _cursor_pos = _cursor_pos-1
        refresh()
    end
end

local function key_ctrl_c()
    -- now is not catch by linenoise, see llinenoise.c
    return false
end

local function key_delete()
    if delete_char(_cursor_pos) then
        refresh()
    end
end

local function key_backspace()
    if delete_char(_cursor_pos-1) then
        _cursor_pos = _cursor_pos-1
        refresh()
    end
end

local function key_ctrl_k()
    if _cursor_pos <= #_line then
        _line = _line:sub(1, _cursor_pos-1)
        refresh()
    end
end

local function key_ctrl_l()
    stdout:write("\x1b[H\x1b[2J")
    refresh()
end

local function key_enter()
    append_history()
    stdout:write('\n')
    stdout:flush()
    return _line
end

local function key_ctrl_t()
    if _cursor_pos > 1 and _cursor_pos <= #_line then
        local c1 = _line:sub(_cursor_pos-1, _cursor_pos-1)
        local c2 = _line:sub(_cursor_pos, _cursor_pos)
        _line = 
        _line:sub(1, _cursor_pos-2)..
        c2..c1..
        _line:sub(_cursor_pos+1)
        refresh()
    end
end

local function key_ctrl_u()
    clear_line()
    refresh()
end

local function key_ctrl_w()
    if _cursor_pos > 1 then
        local s1 = _line:sub(1, _cursor_pos-1)
        local s2 = _line:sub(_cursor_pos)
        local pos = s1:find('[^ ]*[ ]*$')
        s1 = s1:sub(1,pos-1)
        _line = s1..s2
        _cursor_pos = pos
        refresh()
    end
end

local function key_esc(getc)
    local c1 = assert(getc())
    local c2 = assert(getc())
    if c1=='[' then
        if c2>='0' and c2<='9' then
            local c3 = assert(getc())
            if c3=='~' then
                if c2=='3' then
                    key_delete()
                end
            end
        elseif c2=='A' then
            move_up()
        elseif c2=='B' then
            move_down()
        elseif c2=='C' then
            move_right()
        elseif c2=='D' then
            move_left()
        elseif c2=='H' then
            move_home()
        elseif c2=='F' then
            move_end()
        end
    elseif c1=='0' then
        if c2=='H' then
            move_home()
        elseif c2=='F' then
            moev_end()
        end
    end
end

local control = {
    [1] = move_home,        --ctrl-a
    [2] = move_left,        --ctrl-b
    [3] = key_ctrl_c,       --ctrl-c
    [4] = key_delete,       --ctrl-d
    [5] = move_end,         --ctrl-e
    [6] = move_right,       --ctrl-f
    [8] = key_backspace,    --backspace
    [127] = key_backspace,
    [11] = key_ctrl_k,      --ctrl-k
    [12] = key_ctrl_l,      --ctrl-l
    [13] = key_enter,       --ENTER
    [14] = move_down,       --ctrl-n
    [16] = move_up,         --ctrl-p
    [20] = key_ctrl_t,      --ctrl-t
    [21] = key_ctrl_u,      --ctrl-u
    [23] = key_ctrl_w,      --ctrl-w
    [27] = key_esc,         --ESC
}

function linenoise.read(prompt, getc, gets)
    local ok, err
    if c.isatty() then -- Not a tty: read from file / pipe
        ok, err = pcall(gets)
    else
        _prompt = prompt or ''
        ok, err = pcall(function()
            local res
            clear_line()
            assert(c.rawmode_on())
            stdout:write(_prompt)
            stdout:flush()
            while true do
                local c = assert(getc())
                local b = sbyte(c)
                local func = control[b]
                if func then
                    res = func(getc)
                    if res ~= nil then
                        break
                    end
                else
                    append_char(c)
                    refresh()
                end
            end
            return res or nil
        end)
        c.rawmode_off()
    end
    if not ok then
        print('\x1b[31m'..err..'\x1b[0m')
        return ""
    else
        return err
    end
end

function linenoise.history(max)
    _history_max = max or _history_max
end

function linenoise.loadhistory(file)
    if #_historys >= _history_max then
        return true
    end
    local f, err = io.open(file, 'r')
    if f then
        for c in f:lines('l') do
            if #_historys < _history_max then
                if c ~= '' then
                    tinsert(_historys, 1, c)
                end
            else break
            end
        end
        return true
    else
        return nil, err
    end
end

function linenoise.savehistory(file)
    local f, err = io.open(file, 'w')
    if f then
        if _historys[#_historys] == '' and _line ~= '' then
            _historys[#_historys] = _line
        end
        for i=#_historys, 1, -1 do
            local c = _historys[i]
            if c ~= '' then
                f:write(c..'\n')
            end
        end
        f:close()
        return true
    else
        return nil, err
    end
end

return linenoise
