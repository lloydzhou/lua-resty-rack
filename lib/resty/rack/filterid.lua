module(..., package.seeall)

_VERSION = '0.01'

function call(options)
    return function(req, res, next)
        req.args.id = req.args.id or req.uri:match("%x+$")
        if req.args.id:len() ~= 24 then
            res.status = 500
        end
        
        req.options.content_type, req.options.content_desc 
            = "application/zip", "attachment;filename=".. req.args.id .. ".zip"
        req.options.content_type, req.options.content_desc 
            = "application/zip", "attachment;filename=".. req.args.id .. ".zip"
        if ngx.var.arg_type == "config" then 
            req.options.content_type, req.options.content_desc 
                = "text/plain", "attachment;filename=".. req.args.id .. ".config" 
        elseif ngx.var.arg_type == "mp4" then 
            req.options.content_type, req.options.content_desc 
                = "video/mpeg4", "attachment;filename=".. req.args.id .. ".mp4" 
        end

        next()
    end
end

