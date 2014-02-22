module(..., package.seeall)

_VERSION = '0.01'

function call(options)
    return function(req, res, next)
    	req.options = req.options or {}
    	for k,v in pairs(options) do 
	    	req.options[k] = v
	    end
    	res.status = 200
    	next()
    end
end

