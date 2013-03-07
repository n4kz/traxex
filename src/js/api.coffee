Traxex = @Traxex

request = (options) ->
	r = new XMLHttpRequest()
	r.open('POST', options.url)
	r.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded')
	r.setRequestHeader('Accept', 'application/json')
	r.onreadystatechange = ->
		return unless @readyState is 4

		if @status is 200
			options.success(JSON.parse(@response))
		else
			options.error()

	data = ''

	for own field, value of options.data
		data += ';' if data
		data += field.replace(/\s/g, '+') + '=' + encodeURIComponent(value)

	r.send(data or null)

	null

call = (method, options = {}, callback) ->
	options.stream ?= Traxex.config.stream if Traxex.config

	request
		url: '/_?method=' + method
		data: options

		success: (data) ->
			callback(data.error, data.result)

		error: ->
			callback
				error:
					code: '100'
					message: 'Internal error'

	null

for method in ['getTagStream', 'getLinkStream', 'getTagMark', 'getLinkMark', 'getMark', 'getConfig', 'getUser']
	((method) ->
		Traxex[method] = ->
			call.apply(null, [method].concat(Array.prototype.slice.call(arguments)))
	)(method)
