module("resty.rack", package.seeall)

_VERSION = '0.02'

-- lazy loading method would be better.
middleware = setmetatable({}, {__index = function(t, k)
  local ok, new_lib_or_error = pcall(function() return require('resty.rack.' .. k); end)
  if not ok then ngx.log(ngx.ERR, "can not load middleware: " .. k, new_lib_or_error) end
  return ok and rawset(t, k, new_lib_or_error) and new_lib_or_error or nil
end})

-- Register some middleware to be used.
-- @param   string  route       Optional, dfaults to '/'.
-- @param   table   middleware  The middleware module
-- @param   table   options     Table of options for the middleware. 
-- @return  void
function use(...) _use('', ...) end

-- @see use(...)
function after(...) _use('after', ...) end

-- @see use(...)
function before(...) _use('before', ...) end

-- Helper function to register middleware.
function _use(...)
    -- Process the args
    local args = {...}
    local before_or_after, middleware, route, mw, options = nil, nil, nil, nil, nil
    before_or_after = table.remove(args, 1)

    if not ngx.ctx.rack then 
        ngx.ctx.rack = { 
            beforemiddleware = {},
            middleware = {},
            aftermiddleware = {} 
        } 
    end

    middleware = ngx.ctx.rack[before_or_after .. 'middleware']

    route = table.remove(args, 1)
    if type(route) == "table" or type(route) == "function" then
        mw = route
        route = nil
    else
        mw = table.remove(args, 1)
    end
    options = table.remove(args, 1) or {}

    if route then
        -- Only carry on if we have a route match
        if string.sub(ngx.var.uri, 1, route:len()) ~= route then return false end
    end

    if (type(mw) == "table" and type(mw.call) == "function") or type(mw) == "function" then
        -- If we have a 'call' function, then we insert the result into our rack
        -- Or if we simply have a function, we can add that instead
        if (type(mw) == "table" and type(mw.call) == "function") then
            mw = mw.call(options)
        end
        table.insert(middleware, mw)
        -- If we have a 'autorun' key, then we run this application
        if options.autorun then run() end
    else
        return nil, "Invalid middleware"
    end
end
-- Start the rack.
function run()
    -- We need a decent req / res environment to pass around middleware.
    if not ngx.ctx.rack or not ngx.ctx.rack.middleware then 
        ngx.log(ngx.ERR, "Attempted to run rack without any middleware.")
        return
    end

    ngx.ctx.rack.req = {
        method = ngx.var.request_method,
        scheme = ngx.var.scheme,
        uri = ngx.var.uri,
        host = ngx.var.host,
        query = ngx.var.query_string or "",
        args = ngx.req.get_uri_args(),
        header = {},
        body = "",
    }
    ngx.ctx.rack.res = {
        status = nil,
        header = {},
        body = nil,
    }
        
    -- uri_relative = /test?arg=true 
    ngx.ctx.rack.req.uri_relative = ngx.var.uri .. ngx.var.is_args .. ngx.ctx.rack.req.query

    -- uri_full = http://example.com/test?arg=true
    ngx.ctx.rack.req.uri_full = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.ctx.rack.req.uri_relative

    -- Case insensitive request and response headers.
    --
    -- ngx_lua has request headers available case insensitively with ngx.var.http_*, but
    -- these cannot be iternated over or added to (for fake request headers).
    -- Response headers are set to ngx.header.*, and can also be set and read case
    -- insensitively, but they cannot be iterated over.
    -- Ideally, we should be able to set/get headers in req.header and res.header case
    -- insensitively, with optional underscores instead of dashes (for consistency), and
    -- iterate over them (with the case they were set).

    -- For request headers, we must:
    -- * Keep track of fake request headers in a normalised (lowercased / underscored) state.
    -- * First try a direct hit, then fall back to the normalised table, and ngx.var.http_*
    local req_h_mt = {
        normalised = {}
    }

    req_h_mt.__index = function(t, k)
        k = k:lower():gsub("-", "_")
        return req_h_mt.normalised[k] or ngx.var["http_" .. k] 
    end

    req_h_mt.__newindex = function(t, k, v)
        rawset(t, k, v)

        k = k:lower():gsub("-", "_")
        req_h_mt.normalised[k] = v
    end

    setmetatable(ngx.ctx.rack.req.header, req_h_mt)
    
    -- For response headers, we simply keep things proxied and normalised, to be set
    -- to ngx.header.* later.
    local res_h_mt = {
        normalised = {}
    }

    res_h_mt.__index = function(t, k)
        k = k:lower():gsub("-", "_")
        return res_h_mt.normalised[k]
    end

    res_h_mt.__newindex = function(t, k, v)
        rawset(t, k, v)
        k = k:lower():gsub("-", "_")
        res_h_mt.normalised[k] = v
    end

    setmetatable(ngx.ctx.rack.res.header, res_h_mt)

    -- merge all handlers in ngx.ctx.rack.middleware
    for i,v in pairs(ngx.ctx.rack.beforemiddleware) do table.insert(ngx.ctx.rack.middleware, 1, v) end
    for i,v in pairs(ngx.ctx.rack.aftermiddleware ) do table.insert(ngx.ctx.rack.middleware,    v) end

    next()
end

-- Runs the next middleware in the rack.
function next()
    -- Pick each piece of middleware off in order
    local mw = table.remove(ngx.ctx.rack.middleware, 1)

    if type(mw) == "function" then
        local req = ngx.ctx.rack.req
        local res = ngx.ctx.rack.res

        -- Call the middleware, which may itself call next(). 
        -- The first to return is handling the reponse.
        local post_function = mw(req, res, next)

        if not ngx.headers_sent then
            assert(res.status, "Middleware returned with no status. Perhaps you need to call next().")

            -- If we have a 5xx or a 3/4xx and no body entity, exit allowing nginx config
            -- to generate a response.
            if res.status >= 500 or (res.status >= 300 and res.body == nil) then
                ngx.exit(res.status)
            end

            -- Otherwise send the response as normal.
            ngx.status = res.status
            for k,v in pairs(res.header) do
                ngx.header[k] = v
            end
            ngx.print(res.body)
            ngx.eof()
        end

        -- Middleware may return a function to call post-EOF.
        -- This code will only run for persistent connections, and is not really guaranteed
        -- to run, since browser behaviours differ. Also be aware that long running tasks
        -- may affect performance by hogging the connection.
        if post_function and type(post_function == "function") then
            post_function(req, res)
        end
    end
end

-- to prevent use of casual module global variables
getmetatable(resty.rack).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": ' .. debug.traceback())
end
