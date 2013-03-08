container = document.createElement('div')

render = (html) ->
	container.innerHTML = String(html)
	return container.childNodes

find = (name, container = document) ->
	return container.getElementsByClassName(name)

empty = (node) ->
	node.innerHTML = ''

template = (name, data = {}) ->
	return render(Ulfsaar[name](data))[0]

each = (name, container, action) ->
	elements = find(name, container)
	action.call(element) for element in elements

@Traxex.view =
	_:
		control      : 'c'
		search       : 'c-search'
		issues       : 'c-issues-list'
		filters      : 'c-filter-list'
		issueN       : 'c-issues-issue-'
		inner        : 'd-inner'
		message      : 'd-inner-message'
		comments     : 'd-comments'

	ready: no
	filter: 'open'
	current: 0
	filtered: []
	hidden: []

	# Prepare view
	setup: ->
		@issues  = find(@_.issues)[0]
		@filters = find(@_.filters)[0]
		@inner   = find(@_.inner)[0]
		@input   = find(@_.search)[0]

		@input.removeAttribute('style')

		@ready = yes

	# Reset filters
	reset: ->
		each 'action', @filters, ->
			@classList.remove('selected')

		empty(@issues)

	# Render filter list
	renderFilters: (data) ->
		@setup() unless @ready

		filters = ['all']

		for own key of data
			filters.unshift(key)

		empty(@filters)

		for filter in filters
			@filters.appendChild template 'filter', filter: filter

	# Render issues by type
	render: (type = @filter) ->
		@setup() unless @ready
		@reset()

		@filter = type

		each 'action', @filters, ->
			@classList.add('selected') if @getAttribute('data-action') is "render:#{type}"

		@filtered = issues = []

		for own id, issue of Traxex.model.issues when type is 'all' or issue[type]
			issues.push(issue)

		issues = issues.sort (a, b) ->
			`a.id > b.id? -1 : (b.id > a.id? 1 : 0)`

		for issue in issues

			unless issue.node
				issue.selected = issue.id is @current
				issue.type = @_.issueN + issue.id
				issue.node = template 'issue', issue
				issue.text = issue.node.textContent.toLowerCase()

			@issues.appendChild issue.node

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
					issue.node.classList.remove('hidden')

			return

		for issue in @filtered
			unless ~issue.text.indexOf(query)
				issue.node.classList.add('hidden')
				@hidden.push(issue)
			else
				issue.node.classList.remove('hidden')

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
			list = element.classList

			if list.contains(@_.issueN + id)
				list.add('selected')
			else
				list.remove('selected')

		@inner.appendChild(template('header', issue))
		@inner.appendChild(template('comments'))

	# Update issue comments on left side
	update: ->
		id = @current
		data = Traxex.model.comments[id]
		return unless id
		return unless data

		@inner.replaceChild(template('comments', comments: data), find(@_.comments, @inner)[0])

	# Warn about error
	warn: (text) ->
		@setup() unless @ready

		empty(@inner)
		@inner.appendChild template 'message', message: text


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
	<li class="c-issues-issue {{type}}{{#selected}} selected{{/selected}}">
		<span class=c-issues-issue-number>{{>number}}</span>&nbsp;
		<span class=c-issues-issue-name>{{>body}}</span>
	</li>
'''
