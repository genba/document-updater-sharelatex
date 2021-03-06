Keys = require('./RedisKeyBuilder')
Settings = require('settings-sharelatex')
DocumentManager = require "./DocumentManager"
RedisManager = require "./RedisManager"
DocOpsManager = require "./DocOpsManager"
Errors = require "./Errors"

module.exports = ShareJsDB =
	getOps: (doc_key, start, end, callback) ->
		if start == end
			return callback null, []

		# In redis, lrange values are inclusive.
		if end?
			end--
		else
			end = -1

		[project_id, doc_id] = Keys.splitProjectIdAndDocId(doc_key)
		DocOpsManager.getPreviousDocOps project_id, doc_id, start, end, (error, ops) ->
			return callback error if error?
			callback null, ops
	
	writeOp: (doc_key, opData, callback) ->
		[project_id, doc_id] = Keys.splitProjectIdAndDocId(doc_key)
		DocOpsManager.pushDocOp project_id, doc_id, {op:opData.op, meta:opData.meta}, (error, version) ->
			return callback error if error?

			if version == opData.v + 1
				callback()
			else
				# The document has been corrupted by the change. For now, throw an exception.
				# Later, rebuild the snapshot.
				callback "Version mismatch in db.append. '#{doc_id}' is corrupted."

	getSnapshot: (doc_key, callback) ->
		[project_id, doc_id] = Keys.splitProjectIdAndDocId(doc_key)
		DocumentManager.getDoc project_id, doc_id, (error, lines, version) ->
			return callback(error) if error?
			if !lines? or !version?
				return callback(new Errors.NotFoundError("document not found: #{doc_id}"))

			if lines.length > 0 and lines[0].text?
				type = "json"
				snapshot = lines: lines
			else
				type = "text"
				snapshot = lines.join("\n")
			callback null,
				snapshot: snapshot
				v: parseInt(version, 10)
				type: type

	# To be able to remove a doc from the ShareJS memory
	# we need to called Model::delete, which calls this 
	# method on the database. However, we will handle removing
	# it from Redis ourselves
	delete: (docName, dbMeta, callback) -> callback()
