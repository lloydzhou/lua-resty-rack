module(..., package.seeall)

_VERSION = '0.01'

mongo = require "resty.mongol"

function call(options)

    return function(req, res, next)
		
		local tohex = function(s)
		    return s:gsub('.', function(c) return string.format('%02x', string.byte(c)) end)
		end
		local hex2str = function (s)
		    return s:gsub('(%x%x)', function(value) return string.char(tonumber(value, 16)) end)
		end
		local objidformat = function(v) return v.id and tohex(v.id) or v end
		local frameformat = function(v) return v.id and (req.options.framedownload or "") .. tohex(v.id) or v end
		local livezipformat = function(v, t) return v.id and (req.options.zipdownload or "") .. tohex(v.id) .. (t and "?type="..t or "") or v end
		local zipformat = function(v) return livezipformat(v)  end
		local dateformat = function (v) return os.date("%Y-%m-%d %H:%M", v/1000 - 8 * 60 * 60) end
		local default_bson_map = {
		    _id = objidformat, 
		    zip = function(v) return livezipformat(v) end,
		    preview = function(v) return livezipformat(v, "mp4") end,
		    conf = function(v) return livezipformat(v, "config") end,
		    imgid = frameformat,
		    apkid = objidformat,
		    cover = frameformat,
		    thumb = frameformat,
		    atime = dateformat,
		    start = dateformat,
		    ["end"] = dateformat
		}
		local readbson_callback = function (r, map)
		    map = map or default_bson_map
		    for k, v in pairs(r) do
		        if map[k] then 
		            r[k] = map[k](v) 
		        end
		    end
		    return r
		end
	    conn = mongo:new()
	    local ok, err = conn:connect(options.host or "210.14.154.142")
	    if ok then
	        local db = conn:new_db_handle(options.dbname)
	        if db then
	            local col = db:get_col(options.collection)
	            if col then
	                local id, r, t = col:query(options.query or req.options.query or {}, options.fields or req.options.fields or nil, 
	                	options.skip or req.options.skip or 0, options.limit or req.options.limit or 20, nil, options.bson_callback or readbson_callback)   
	                req.data = options.callback and options.callback(r) or r
	                options.callback = ""
	                req.options = options
	                conn:set_keepalive(60, 500)
	                res.status = 200
	                return next()
	            else
	                ngx.say("can not get collection.")
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

