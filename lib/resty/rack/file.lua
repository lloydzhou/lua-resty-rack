module(..., package.seeall)

_VERSION = '0.01'

local ObjectId = require "resty.mongol.ObjectId"
local mongo = require "resty.mongol"

function call(options)
    local hex2str = function (s)
        return s:gsub('(%x%x)', function(value) return string.char(tonumber(value, 16)) end)
    end
    
    local hex2objid = function (hex) return ObjectId(hex2str(hex)) end

    return function(req, res, next)
	    for k,v in pairs(options) do 
	    	req.options[k] = v
	    end
	    conn = mongo:new()
        local ok, err = conn:connect(req.options.host)
        if ok then
            local db = conn:new_db_handle(req.options.dbname)
            if db then
                local fs = db:get_gridfs("fs")
                if fs then
                    local gf = fs:find_one({_id = hex2objid(req.args.id) })
                    if not gf then 
                        ngx.exit(ngx.HTTP_NOT_FOUND)
                    end
                    -- get the offset and size from http range header
                    local range = req.header.range or "bytes=0-"
                    range = range:gsub("bytes=", "")
                    local i = range:find("-") or 1
                    local l = range:len()
                    local offset, size = nil, nil
                    if i == 1 then 
                        offset, size = 0, tonumber(range:sub(i+1), 10)
                    elseif i == l then
                        offset, size = tonumber(range:sub(1, i-1), 10), nil 
                    else                    
                        offset, size = tonumber(range:sub(1, i-1), 10), tonumber(range:sub(i+1), 10)
                        size = size - offset
                    end

                    res.header.content_type = req.options.content_type or "image/png";
                    if content_desc then 
                        ngx.header.content_disposition = req.options.content_desc;
                    end
                    res.body = gf:read(size, offset)
                    res.status = 200
                    conn:set_keepalive(60, 500)
                	return next()
                else
                    ngx.say("can not get gridfs.")
                end
            else
                ngx.say("can not select db.")
            end
        else
            ngx.say("connect failed: ".. err)
        end
        res.status = 500
        conn:set_keepalive(60, 500)
    	next()
    end
end
