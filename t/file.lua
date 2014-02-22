rack.before(rack.middleware.config, {
	host = "210.14.154.142", 
	dbname = "androidesk_ipai",
	collection = "version",
	query = {},
	fields = nil,
	skip = tonumber(req.args.skip) or 0, 
	limit = tonumber(req.args.limit) or 20,
	framedownload = "http://localhost/frame/download/",
	zipdownload = "http://localhost/livezip/download/"
})

rack.after(rack.middleware.etag)

rack.use(rack.middleware.filterid)

rack.use("/download/frame", rack.middleware.file, {content_type = "image/png", content_desc = nil, dbname = "androidesk_ipai_files"})

rack.use("/download/livezip", rack.middleware.file, {dbname = "androidesk_ipai_files"})

rack.run()
