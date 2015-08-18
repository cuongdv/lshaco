local shaco = require "shaco"
local tbl = require "tbl"
local dsetupvalue = debug.setupvalue
local dgetupvalue = debug.getupvalue
local dupvaluejoin = debug.upvaluejoin
local sfmt = string.format
local srep = string.rep
local tinsert = table.insert
local pairs = pairs
local loadfile = loadfile
local assert = assert
local type = type

local hotfix = {}
local __cache 

local function __getupvaluei(f, name)
    local i=1
    while true do
        local n, v = dgetupvalue(f, i)
        if not n then
            break
        elseif n == name then
            return i
        end
        i = i+1
    end
end

local function __collect_up_f(f, name, upold, upnew, ups)
    if __cache[name] then
        return
    end
    local i = 1
    while true do
        local upn, upv = dgetupvalue(f, i)
        if not upn then
            break
        end
        if upv == upold then
            tinsert(ups, {f, i, upnew, name, upn})
        elseif type(upv) == "function" then
            __collect_up_f(upv, upn, name, upold, upnew, ups)
        end
        i = i+1
    end
end

local function __collect_up_t(t, name, upold, upnew, ups)
    if __cache[name] then
        return
    end
    for k, v in pairs(t) do
        local fulln = name.."."..k
        if type(v) == "table" then
            --__collect_up_t(v, fulln, upold, upnew, ups)
        elseif type(v) == "function" then
            __collect_up_f(v, fulln, upold, upnew, ups)
        end
    end
end

local function __collect_up_all(upold, upnew)
    local ups = {}
    for k, p in pairs(package.loaded) do
        __cache = {}
        local fulln = k
        if type(p) == "table" then
            __collect_up_t(p, fulln, upold, upnew, ups)
        elseif type(p) == "function" then
            __collect_up_f(p, fulln, upold, upnew, ups)
        end
    end
    return ups
end

local function __collect_patch_fun_ups(fnew, fold)
    local ups = {}
    local i = 1
    while true do
        local upn, upv = dgetupvalue(fnew, i)
        if not upn then
            break
        end
        if type(upv) ~= "function" then
            tinsert(ups, {upn, i, __getupvaluei(fold, upn)})
        end
        i = i+1
    end
    return ups
end

local function __collect_patch_funs(name, pnew, pold)
    local funcs = {}
    if type(pnew) == "table" then
        for k, v in pairs(pnew) do
            if type(v) == "function" then
                local oldv = pold[k]
                if oldv then
                    assert(type(oldv) == type(v), sfmt("Hotfix %s.%s type mismatch", name, k))
                    tinsert(funcs, {k, v, oldv, __collect_patch_fun_ups(v, oldv)})
                else
                    tinsert(funcs, {k, v, nil})
                end
            else
                --error(sfmt("Hotfix %s.%s has invalid type %s", name, k, type(v)))
            end
        end
    elseif type(pnew) == "function" then
        tinsert(funcs, {name, pnew, pold, __collect_patch_fun_ups(pnew, pold)})
    else
        error(sfmt("Hotfix %s has invalid type %s", name, type(pnew)))
    end
    return funcs 
end

local function LVL(level)
    return "|"..srep("_", level)
end

local function __fix_funcs(name, pkg, funcs)
    -- save old local
    if type(pkg) == "table" then
        for _, f in ipairs(funcs) do
            if f[3] then
                shaco.info(sfmt("%sfunction U: %s", LVL(1), f[1]))
                for _, up in ipairs(f[4]) do
                    if up[3] then
                        dupvaluejoin(f[2], up[2], f[3], up[3])
                        shaco.info(sfmt("%supvalue U: [%d->%d] %s", LVL(2), up[2], up[3], up[1]))
                    else
                        shaco.info(sfmt("%supvalue A: [%d] %s", LVL(2), up[2], up[1]))
                    end
                end
            else
                shaco.info(sfmt("%sfunction A: %s", LVL(1), f[1]))
            end
            pkg[f[1]] = f[2] -- replace
        end
    elseif type(pkg) == "function" then
        assert(#funcs == 1)
        local f = funcs[1]
        assert(pkg == f[3])
        package.loaded[name] = f[2] 
    end
end

local function __replace_ups(ups, level)
    for _, up in ipairs(ups) do
        dsetupvalue(up[1], up[2], up[3])
        shaco.info(sfmt("%supvalue R: %s [%d] %s", LVL(level), up[4], up[2], up[5]))
    end
end

local function __replace_funcs(funcs, level)
    for _, f in ipairs(funcs) do
        if f[3] then
            local name = f[1]
            shaco.info(sfmt("%sfunction R: %s", LVL(level), name))
            local ups = __collect_up_all(f[3], f[2])
            __replace_ups(ups, level+1)
        end
    end
end

local function __load_patch(name, file)
    local p = package.loaded[name]
    assert(p, sfmt("Hotfix package `%s` no found", name))
    local f, err = loadfile(file)
    assert(f, err)
    return p, f()
end

local function hotfix(name, patch, mode)
    local file = patch
    shaco.info(sfmt("Hotfix %s `%s` ...", name, file))
    local pold, pnew = __load_patch(name, file)
    assert(type(pold) == type(pnew), sfmt("Hotfix package type dismatch"))
    if mode == "U" then
        local funcs = __collect_patch_funs(name, pnew, pold)
        __fix_funcs(name, pold, funcs)
        __replace_funcs(funcs, 1)
    elseif mode == "R" then
        local ups = __collect_up_all(pold, pnew)
        __replace_ups(ups, 1)
        package.loaded[name] = pnew
    else
        error(sfmt("Hotfix mode %s invalid", tostring(mode)))
    end 
    shaco.info(sfmt("Hotfix %s `%s` ok", name, file))
end

return hotfix
