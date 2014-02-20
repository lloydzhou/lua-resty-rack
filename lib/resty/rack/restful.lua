module(..., package.seeall)

_VERSION = '0.01'

local cjson = require "cjson"
function call(options)
    return function(req, res, next)
    	local content = cjson.encode({code = 0, resp = req.data or {}, options = req.options or {}})
    	local etag = ngx.md5(content) 
    	if req.header["If-None-Match"] and req.header["If-None-Match"] == etag then 
    		res.status = 304
    	else
    		res.header["ETag"] = etag
    		res.header["Cache-Control"] = "no-transform,public,max-age=300,s-maxage=900"
    		res.header.content_type = "text/plain; charset = utf-8"; 
    		res.body = content
	    end
    	next()
    end
end
