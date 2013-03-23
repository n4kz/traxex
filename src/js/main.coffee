Traxex = @Traxex =
	timer: null
	project: null

	# Update interface
	update: (changes, initial) ->
		clearTimeout(@timer) if initial

		id = @view.current or location.hash.slice(1)

		unless @project
			if id
				@model.fetchIssue id, (issue) =>
					if issue
						@$select issue.stream
					else
						@view.open()
					return
			else
				@view.open()

			return

		if changes
			@view.render(@project)
			@view.open(id)

			if id
				if initial and @model.comments[id]
					@view.update()
				else
					@model.fetchComments id, 0, =>
						@view.update()

		@timer = setTimeout((=>
			@model.check @project, =>
				@update(arguments[0])
		), @config.timeout)

	# Select another project
	$select: (project) ->
		if project isnt @project
			@model.setup @project = project, =>
				# Render filters
				@view.renderFilters project, @model.types[project]

				# Check project for updates
				if @model.synced[project]
					@update(yes, yes)
				else
					@model.check project, =>
						@update(yes, yes)

	# Filter issue list
	$render: (filter) ->
		@view.render(@project, filter)
		@view.search()

	# Show issue details
	$open: (id) ->
		return if id is @view.current

		issue = @model.issues[id]

		@view.open(id)
		return @view.render() unless id

		if not issue
			@project = @view.current = null
			@update(yes, yes)
			return

		if issue.stream isnt @project
			@view.current = null
			@$select(issue.stream)
			return

		if @model.comments[id]
			@view.update()
		else
			@model.fetchComments id, 0, =>
				@view.update()

Gator(document).on 'readystatechange', ->
	return if document.readyState isnt 'complete'

	Gator(document).on 'click', '.action', (event) ->
		action = event.target.getAttribute('data-action').split(':')

		Traxex['$' + action[0]](action[1])

		return no

	Gator(document).on 'keyup', '.' + Traxex.view._.search, (event) ->
		Traxex.view.search(event.target.value)

	Gator(window).on 'hashchange', ->
		Traxex.$open(location.hash.slice(1))

	Traxex.view.setup()
	Traxex.model.setup null, ->
		Traxex.update(yes, yes)
