module(..., package.seeall)

_VERSION = '0.01'

function call(options)
    return function(req, res, next)
    	req.options = req.options or {
    		host = "210.14.154.142", 
    		dbname = "androidesk_ipai",
    		collection = "version",
    		query = {},
    		fields = nil,
    		skip = tonumber(req.args.skip) or 0, 
    		limit = tonumber(req.args.limit) or 20,
    		framedownload = "http://localhost/frame/download/",
    		zipdownload = "http://localhost/livezip/download/"
    	}
    	for k,v in pairs(options) do 
	    	req.options[k] = v
	    end
    	res.status = 200
    	next()
    end
end

