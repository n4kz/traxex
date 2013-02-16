@Traxex.view =
	_:
		data         : '.d '
		templates    : '.t '
		control      : '.c '
		filters      : '.c-filter-list'
		issues       : '.c-issues-list'
		issue        : '.c-issues-issue'
		issueNumber  : '.c-issues-issue-number'
		issueName    : '.c-issues-issue-name'
		inner        : '.d-inner'
		header       : '.d-header'
		headerNumber : '.d-header-number'
		headerName   : '.d-header-name'
		headerAuthor : '.d-header-author'
		headerTime   : '.d-header-time'
		comments     : '.d-comments'
		comment      : '.d-comments-comment'
		text         : '.d-comments-comment-text'
		author       : '.d-comments-comment-author'
		time         : '.d-comments-comment-time'

	ready: no
	filter: 'open'
	current: 0

	setup: ->
		@issue = $(@_.templates + @_.issue)
			.detach()

		@header = $(@_.templates + @_.header)
			.detach()

		@comment = $(@_.templates + @_.comment)
			.detach()

		@comments = $(@_.templates + @_.comments)
			.detach()

		@issues = $(@_.templates + @_.issues)
			.appendTo($(@_.control))

		@filters = $(@_.filters)
		@inner   = $(@_.inner)

		@ready = yes

	reset: ->
		@filters
			.find('.action')
			.removeClass('selected')

		@issues.empty()

	renderFilters: (data) ->
		@setup() unless @ready

		filters = ['all']

		for own key of data
			filters.unshift(key)

		@filters.empty()

		for filter in filters
			@filters.append(getFilter(filter))

	render: (type = @filter) ->
		@setup() unless @ready
		@reset()

		@filter = type

		@filters.find('.action')
			.filter("[data-action=\"render:#{type}\"]")
			.addClass('selected')

		# TODO: sort
		for own id, issue of Traxex.model.issues when type is 'all' or issue[type]
			node = @issue
				.clone()
				.appendTo(@issues)

			node.find(@_.issueName).html(getName(issue))
			node.find(@_.issueNumber).html(getNumber(issue))

	clear: () ->
		@inner.empty()

	open: (id) ->
		return if id and @current is id

		issue    = Traxex.model.issues[id]
		comments = Traxex.model.comments[id] or []

		@clear()
		return unless issue

		@current = location.hash = id

		header = @header.clone()
			.appendTo(@inner)

		header.find(@_.headerName).html(getName(issue))
		header.find(@_.headerNumber).html(getNumber(issue))
		header.find(@_.headerAuthor).text(issue.meta.author.name)
		header.find(@_.headerTime).text(getTime(issue))

		@comments.clone()
			.appendTo(@inner)

	update: () ->
		id = @current
		return unless id
		return unless Traxex.model.comments[id]

		comments = @inner
			.find(@_.comments)
			.empty()

		# TODO: sort
		for data in Traxex.model.comments[id]
			(comment = @comment.clone())
				.find(@_.text)
				.html(data.body)

			comment.find(@_.author).text(data.meta.author.name)
			comment.find(@_.time).text(getTime(data))
			comment.appendTo(comments)

getName = (issue) ->
	$(issue.body)
		.first()
		.html()

getNumber = (issue) ->
	"""<a class=action data-action=open:#{issue.id} href=##{issue.id}>##{issue.id}</a>"""

getFilter = (filter) ->
	"""
		<li>
			<a class=action data-action=render:#{filter} href=javascript:void(0)>#{filter}</a>
		</li>
	"""

getTime = (message) ->
	(new Date(message.time)).toLocaleString()
