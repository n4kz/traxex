Traxex = @Traxex

request = (options) ->
	r = new XMLHttpRequest()
	r.open('POST', options.url)
	r.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded')
	r.setRequestHeader('Accept', 'application/json')
	r.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
	r.onreadystatechange = ->
		if @readyState is 4
			if @status is 200
				options.success(JSON.parse(@response))
			else
				options.error()
		return

	data = ''

	for own field, value of options.data
		data += ';' if data
		data += field.replace(/\s/g, '+') + '=' + encodeURIComponent(value)

	r.send(data or null)

	return

# Call API method
call = (method, options, callback) ->
	request
		url: '/_?method=' + method
		data: options || {}

		success: (data) ->
			callback(data.error, data.result)
			return

		error: ->
			callback
				error:
					code: '100'
					message: 'Internal error'
			return

	return

# Create shortcuts for API method calls
for method in ['getTagStream', 'getLinkStream', 'getMark', 'getConfig', 'getUser', 'getSubscriptions', 'getMessage']
	((method) ->
		Traxex[method] = (options, callback) ->
			call(method, options, callback)
			return
		return
	)(method)
