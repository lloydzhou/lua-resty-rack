module(..., package.seeall)

_VERSION = '0.01'

function call(options)
    return function(req, res, next)
    	req.options = {
    		host = "210.14.154.142", 
    		dbname = "androidesk_ipai",
    		collection = "version",
    		query = {},
    		fields = nil,
    		skip = 0, 
    		limit = 20
    	}
    	res.status = 200
    	next()
    end
end

