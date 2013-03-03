@Traxex.view =
	_:
		data         : '.d '
		control      : '.c '
		filters      : '.c-filter-list'
		issues       : '.c-issues-list'
		issueN       : '.c-issues-issue-'
		inner        : '.d-inner'
		header       : '.d-header'
		comments     : '.d-comments'

	ready: no
	filter: 'open'
	current: 0

	setup: ->
		@issues = $('<ul class=c-issues-list></ul>')
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
			@filters.append Ulfsaar.filter filter: filter

	render: (type = @filter) ->
		@setup() unless @ready
		@reset()

		@filter = type

		@filters.find('.action')
			.filter("[data-action=\"render:#{type}\"]")
			.addClass('selected')

		issues = []

		for own id, issue of Traxex.model.issues when type is 'all' or issue[type]
			issues.push(issue)

		issues = issues.sort (a, b) ->
			`a.id > b.id? -1 : (b.id > a.id? 1 : 0)`

		for issue in issues
			@issues.append Ulfsaar.issue $.extend issue,
				selected: issue.id is @current
				type: @_.issueN.slice(1) + issue.id

	clear: () ->
		@inner.empty()

	open: (id) ->
		return if id and @current is id

		issue    = Traxex.model.issues[id]
		comments = Traxex.model.comments[id] or []

		@clear()
		return unless issue

		@current = location.hash = Number(id)

		@issues
			.children()
			.removeClass('selected')
			.filter(@_.issueN + id)
			.addClass('selected')

		@inner.append Ulfsaar.header issue
		@inner.append Ulfsaar.comments {}

	update: () ->
		id = @current
		data = Traxex.model.comments[id]
		return unless id
		return unless data

		@inner
			.find(@_.comments)
			.replaceWith Ulfsaar.comments comments: data

Ulfsaar.time = (scope) ->
	return (new Date(scope('time'))).toLocaleString()

Ulfsaar.body = (scope) ->
	return $(scope('body')).first().html()

Ulfsaar 'number', '<a class=action data-action=open:{{id}} href=#{{id}}>#{{id}}</a>'

Ulfsaar 'filter', '''
	<li>
		<a class=action data-action=render:{{filter}} href=javascript:void(0)>{{filter}}</a>
	</li>
'''

Ulfsaar 'header', '''
	<div class=d-header>
		<span class=d-header-number>{{>number}}</span>
		<span class=d-header-name>{{>body}}</span>
		<br>
		<span class=d-header-author>{{meta.author.name}}</span>
		<span class=d-header-time>{{>time}}</span>
	</div>
'''

Ulfsaar 'comments', '''
	<ul class=d-comments>
		{{#comments}}
			<li class=d-comments-comment>
				<span class=d-comments-comment-author>{{meta.author.name}}</span>
				<span class=d-comments-comment-time>{{>time}}</span>
				<div class=d-comments-comment-text>{{&body}}</div>
			</li>
		{{/comments}}
	</ul>
'''

Ulfsaar 'issue', '''
	<li class="c-issues-issue {{type}}{{#selected}} selected{{/selected}}">
		<span class=c-issues-issue-number>{{>number}}</span>
		<span class=c-issues-issue-name>{{>body}}</span>
	</li>
'''
