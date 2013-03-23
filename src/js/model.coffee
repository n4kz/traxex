Traxex = @Traxex

Traxex.model =
	offset: null
	projects: null
	synced: {}
	types: {}
	issues: {}
	comments: {}
	ready: no

	prepare: (callback) ->
		Traxex.getConfig null, (error, result) =>
			throw new Error(error.message) if error

			@offset = (Traxex.config = result.config).fetchCount
			callback()

	setup: (project, callback) ->
		# Get config
		unless @ready
			return @prepare =>
				@ready = yes
				@setup(project, callback)

		# Fetch user's projects
		unless @projects
			return @fetchProjects =>
				@setup(project, callback)

		return callback() unless project

		# Check access
		unless @projects[project]
			return alert('Access denied')

		Traxex.view.renderProject(project)

		# Load types
		unless @types[project]
			return @fetchTypes(project, callback)

		callback()

	check: (project, callback) ->
		Traxex.getMark { stream: project }, (error, result) =>
			mark = +result.mark

			if not @synced[project] or @synced[project] < mark
				remains = 0

				for own type of @types[project]
					remains++
					@fetchIssues project, 0, type, ->
						unless --remains
							callback(yes)

				@synced[project] = mark
			else
				callback(no)

			return

	fetchProjects: (callback) ->
		Traxex.getSubscriptions null, (error, result) =>
			return alert(error.message) if error

			@projects = {}
			@projects[project] = yes for project in result.streams

			callback()

	fetchTypes: (project, callback) ->
		Traxex.getTagStream { stream: project, tag: ':type' }, (error, result) =>
			throw new Error(error.message) if error

			@types[project] = {}

			for type in result.stream
				@types[project][type.body] = type.id

			callback()

	fetchIssues: (project, mark, type, callback) ->
		options = message: @types[project][type]
		options.mark = mark if mark
		options.stream = project

		Traxex.getLinkStream options, (error, result) =>
			for issue in result.stream
				if issue.meta.type is 'issue'
					issue[type] = yes
					@issues[issue.id] = issue

			if result.stream.length is @offset
				@fetchIssues project, result.stream[result.stream.length - 1].time, type, callback
			else
				callback()

			return

	fetchIssue: (id, callback) ->
		return callback(@issues[id]) if @issues[id]

		# Fetch single message to get stream name
		Traxex.getMessage message: id, (error, result) ->
			callback(if result and result.meta.type is 'issue' then result else null)

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

			return
