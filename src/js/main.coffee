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
					@$select issue.stream if issue
			return

		if changes
			@view.render()

			if id
				@model.fetchComments id, 0, =>
					@view.open(id) if initial
					@view.update()

		@timer = setTimeout((=>
			@model.check @project, =>
				@update(arguments[0])
		), @config.timeout)

	###
		Actions
	###

	# Select another project
	$select: (project) ->
		if project isnt @project
			@model.setup @project = project, =>
				# Render filters
				@view.renderFilters @model.types[project]

				# Get data for the first time
				@model.check project, =>
					@update(yes, yes)

	# Filter issue list
	$render: (filter) ->
		Traxex.view.render(filter)
		Traxex.view.search()

	# Show issue details
	$open: (id) ->
		return if id is Traxex.view.current

		Traxex.view.open(id)
		return unless id

		if Traxex.model.comments[id]
			Traxex.view.update()
		else
			Traxex.model.fetchComments id, 0, ->
				Traxex.view.update()

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

	Traxex.update(yes, yes)
