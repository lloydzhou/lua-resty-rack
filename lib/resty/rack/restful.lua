module(..., package.seeall)

_VERSION = '0.01'

local cjson = require "cjson"
function call(options)
    return function(req, res, next)
        if req.args.callback then
        	res.body = req.args.callback .. "(" 
        	    .. cjson.encode({code = 0, resp = res.body or nil, options = req.options or nil})
        	    --.. cjson.encode({code = 0, resp = res.body or nil})
        	    .. ")"
        	res.header.content_type = "application/javascript; charset = utf-8"; 
        else
        	res.body = cjson.encode({code = 0, resp = res.body or nil, options = req.options or nil})
        	--res.body = cjson.encode({code = 0, resp = res.body or nil})
        	res.header.content_type = "application/json; charset = utf-8"; 
        end
    	next()
    end
end
