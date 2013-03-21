container = document.createElement('div')

render = (html) ->
	container.innerHTML = String(html)
	return container.childNodes

find = (name, container) ->
	return (container or document).getElementsByClassName(name)

empty = (node) ->
	node.innerHTML = ''
	return

template = (name, data = {}) ->
	return render(Ulfsaar[name](data))[0]

each = (name, container, action) ->
	action.call(element) for element in find(name, container)
	return

set = (node, name, set) ->
	node.classList[`set? 'add' : 'remove'`](name)
	return

@Traxex.view =
	_:
		control      : 'c'
		search       : 'c-search'
		issues       : 'c-issues'
		filters      : 'c-filters'
		project      : 'c-project'
		issueN       : 'c-issues-issue-'
		inner        : 'd-inner'
		message      : 'd-inner-message'
		comments     : 'd-comments'

	ready: 0
	filter: null
	current: 0
	filtered: []
	hidden: []

	# Prepare view
	setup: ->
		@issues  = find(@_.issues)[0]
		@filters = find(@_.filters)[0]
		@inner   = find(@_.inner)[0]
		@project = find(@_.project)[0]

		find(@_.search)[0].removeAttribute('style')

		@ready = 1
		return

	# Reset filters
	reset: ->
		each 'action', @filters, ->
			set(@, 'selected', no)

		empty(@issues)
		return

	renderProject: (project) ->
		@setup() unless @ready

		@project.innerHTML = project
		return

	# Render filter list
	renderFilters: (data) ->
		@setup() unless @ready

		filters = Object.keys(data).sort (a, b) ->
			`data[a] > data[b]? 1 : -1`

		filters.push('all')
		@filter = filters[0]

		empty(@filters)

		for filter in filters
			@filters.appendChild template 'filter', filter: filter

		return

	# Render issues by type
	render: (project, type = @filter) ->
		@setup() unless @ready
		@reset()

		@filter = type

		each 'action', @filters, ->
			set(@, 'selected', yes) if @getAttribute('data-action') is "render:#{type}"

		@filtered = issues = []

		for own id, issue of Traxex.model.issues
			if issue.stream is project and (type is 'all' or issue[type])
				issues.push(issue)

		issues = issues.sort (a, b) ->
			`a.id < b.id? 1 : -1`

		for issue in issues

			unless issue.node
				issue.type = @_.issueN + issue.id
				issue.node = template 'issue', issue
				issue.text = issue.node.textContent.toLowerCase()

			set(issue.node, 'selected', issue.id is @current)

			@issues.appendChild issue.node

		return

	search: (query) ->
		hidden  = @hidden
		@hidden = []

		if query is undefined
			query = @lastSearch or ''
		else
			@lastSearch = query = query.toLowerCase()

		unless query
			if hidden.length
				for issue in hidden
					set(issue.node, 'hidden', no)

			return

		for issue in @filtered
			unless ~issue.text.indexOf(query)
				set(issue.node, 'hidden', yes)
				@hidden.push(issue)
			else
				set(issue.node, 'hidden', no)

		return

	# Render selected issue on left side
	open: (id) ->
		return if id and @current is id

		issue    = Traxex.model.issues[id]
		comments = Traxex.model.comments[id] or []

		empty(@inner)
		return unless issue

		@current = location.hash = Number(id)

		issues = @issues.childNodes

		for element in issues
			set(element, 'selected', element.classList.contains(@_.issueN + id))

		@inner.appendChild(template('header', issue))
		@inner.appendChild(template('comments'))
		return

	# Update issue comments on left side
	update: ->
		data = Traxex.model.comments[@current]
		return unless data

		@inner.replaceChild(template('comments', comments: data), find(@_.comments, @inner)[0])
		return

	# Warn about error
	warn: (text) ->
		@setup() unless @ready

		empty(@inner)
		@inner.appendChild template 'message', message: text
		return

Ulfsaar.time = (scope) ->
	return (new Date(scope('time'))).toLocaleString()

Ulfsaar.body = (scope) ->
	return render(scope('body'))[0].innerHTML

Ulfsaar 'number', '<a class=action data-action=open:{{id}} href=#{{id}}>#{{id}}</a>'

Ulfsaar 'message', '<h1 class=d-inner-message>{{message}}</h1>'

Ulfsaar 'filter', '''
	<li>
		<a class=action data-action=render:{{filter}} href=javascript:void(0)>{{filter}}</a>
	</li>
'''

Ulfsaar 'header', '''
	<div class=d-header>
		<span class=d-header-number>{{>number}}</span>&nbsp;
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
	<li class="c-issues-issue {{type}}">
		<span class=c-issues-issue-number>{{>number}}</span>&nbsp;
		<span class=c-issues-issue-name>{{>body}}</span>
	</li>
'''
