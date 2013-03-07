Traxex = @Traxex = {}

Gator(document).on 'readystatechange', ->
	return if document.readyState isnt 'complete'

	update = (changes, initial) ->
		id = Traxex.view.current or location.hash.slice(1)

		if changes
			Traxex.view.render()

			if id
				Traxex.model.fetchComments id, 0, ->
					Traxex.view.open(id) if initial
					Traxex.view.update()

		setTimeout((->
			Traxex.model.check(update)
		), 20000)

	# Setup model
	Traxex.model.setup ->
		# Render filters
		Traxex.view.renderFilters Traxex.model.types

		# Get data for the first time
		Traxex.model.check ->
			update(yes, yes)

	Gator(document).on 'click', '.action', (event) ->
		action = event.target.getAttribute('data-action').split(':')

		actions[action[0]](action[1])

		return no

	Gator(document).on 'keyup', '.' + Traxex.view._.search, (event) ->
		Traxex.view.search(event.target.value)

	Gator(window).on 'hashchange', ->
		actions.open(location.hash.slice(1))

actions =
	render: (filter) ->
		Traxex.view.render(filter)
		Traxex.view.search()

	open: (id) ->
		return if id is Traxex.view.current

		Traxex.view.open(id)
		return unless id

		if Traxex.model.comments[id]
			Traxex.view.update()
		else
			Traxex.model.fetchComments id, 0, ->
				Traxex.view.update()
