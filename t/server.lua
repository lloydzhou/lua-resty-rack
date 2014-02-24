local cjson = require "cjson"
local prefix = "/live"
local gettagcolor = function(mtag, name)
    local reqs, tag = {}, {} 
    for i,v in pairs(mtag) do
        if v ~= (name or nil) then
            table.insert(reqs, {prefix.."/tagcolor?name="..v})
            table.insert(tag, {name=v})
        end
    end
    if table.getn(reqs) > 0 then
        for i, res in ipairs({ ngx.location.capture_multi(reqs) }) do tag[i]["color"] = cjson.decode(res.body).resp end
    end
    return tag
end

rack.before(rack.middleware.config, {
	host = "210.14.154.142", 
	dbname = "androidesk_ipai",
	collection = "version",
	query = {},
	fields = nil,
	skip = tonumber(ngx.var.arg_skip) or 0, 
	limit = tonumber(ngx.var.arg_limit) or 20,
	framedownload = "http://wuhan-dev/download/frame/",
	zipdownload = "http://wuhan-dev/download/livezip/"
})
rack.after(rack.middleware.restful)
rack.after(rack.middleware.etag)

rack.use(prefix.."/message", rack.middleware.mongol, {collection = "message", callback=function(r) return r[1] or r end})

rack.use(prefix.."/apk/list", rack.middleware.mongol, {collection = "live_apk", callback=function(r) 
    for i,v in pairs(r) do r[i]["imgid"] = r[i]["imgid"]:match("%x+$") end
return r end})

rack.use(prefix.."/cate", rack.middleware.mongol, {collection = "category", query={query={}, orderby={rank=1}}, fields={tag=0} }) 

rack.use(prefix.."/list", function(req,res,next)
    if ngx.var.arg_id then
        rack.use(rack.middleware.mongol, {collection = "live_material", 
            query={_id=rack.middleware.file.hex2objid(ngx.var.arg_id)}, callback=function(r) 
                if r[1] and r[1]["tag"] then r[1]["tag"] = gettagcolor(r[1]["tag"], r[1]["name"]) end
            return r[1] end}) 
    else
        rack.use(rack.middleware.mongol, {collection = "live_material",
            query={query={}, orderby={[ngx.var.arg_order or "atime"]=-1}}, callback=function(r)
                for j,m in pairs(r) do r[j]["tag"] = gettagcolor(r[j]["tag"], r[j]["name"]) end
            return r end })
    end
    next()
end)

rack.use(prefix.."/hottag", rack.middleware.mongol, {collection = "category", query={query={}, orderby={num=-1}},
    fields={name=1, _id=0}, callback=function(r)  
        for i,v in pairs(r) do r[i] = r[i]["name"] end
    return gettagcolor(r) end})

rack.use(prefix.."/banner", rack.middleware.mongol, {autorun = true, collection = "live_banner", 
    query={query={active=true}, orderby={num=1}}, fields={itime=0, active=0, num=0} })

rack.use(prefix.."/tagcolor", function(req, res, next) 
    local query = ngx.var.arg_name and {name = ngx.unescape_uri(ngx.var.arg_name)} or {} 
    rack.use(rack.middleware.mongol, {collection = "tag", query=query, callback=function(r) 
    if r[1] and r[1].cid then 
        rack.use( rack.middleware.mongol, {collection = "tag_category", 
            query={_id=r[1].cid },
            callback=function(r) return r[1] and r[1].color end})
    end
    return nil end})
    next()
end)

rack.run()
