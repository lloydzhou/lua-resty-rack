module(..., package.seeall)

_VERSION = '0.01'

local cjson = require "cjson"
function call(options)
    return function(req, res, next)
        if type(res.body)  == 'string' then
        	local etag = ngx.md5(res.body) 
        	if req.header["If-None-Match"] and req.header["If-None-Match"] == etag then 
        		res.status = 304
        	else
        		res.header["ETag"] = etag
        		res.header["Cache-Control"] = "no-transform,public,max-age=300,s-maxage=900"
	        end
	    end
	    res.header.content_type = res.header.content_type or "text/plain; charset=uf-8;"
	    next()
    end
end

