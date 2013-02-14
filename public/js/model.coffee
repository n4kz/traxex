Traxex = @Traxex
# TODO: check for errors
Traxex.model =
	synced   : 0
	offset   : 50
	types    : {}
	issues   : {}
	comments : {}
	ready    : no

	setup: (callback) ->
		Traxex.getTagStream tag: ':type', (error, result) =>
			for type in result.stream
				@types[type.body] = type.id

			@ready = yes
			callback()

	check: (callback) ->
		Traxex.getMark {}, (error, result) =>
			mark = +result.mark

			if @synced < mark
				remains = 0

				for own type of @types
					remains++
					@fetchIssues 0, type, ->
						unless --remains
							callback(yes)

				@synced = mark
			else
				callback(no)

	fetchIssues: (mark, type, callback) ->
		options = message: @types[type]
		options.mark = mark if mark

		Traxex.getLinkStream options, (error, result) =>
			for issue in result.stream
				continue if issue.meta.type isnt 'issue'

				issue[type] = yes
				@issues[issue.id] = issue

			if result.stream.length is @offset
				@fetchIssues result.stream[result.stream.length - 1].time, type, callback
			else
				callback()

	fetchComments: (id, mark, callback) ->
		options = message: id
		options.mark = mark if mark

		# Init or reset comments cache
		unless mark and @comments[id]
			@comments[id] = []

		# Get comments
		Traxex.getLinkStream options, (error, result) =>
			for comment in result.stream
				if comment.meta.type is 'comment'
					@comments[id].unshift(comment)

			if result.stream.length is @offset
				@fetchComments id, result.stream[result.stream.length - 1].time, callback
			else
				callback()

