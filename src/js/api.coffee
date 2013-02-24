Traxex = @Traxex

call = (method, options, callback) ->
	options ?= {}
	options.stream ?= Traxex.config.stream if Traxex.config

	$.ajax
		url: '/_?method=' + method
		type: 'POST'
		data: options
		dataType: 'json'

		success: (data) ->
			callback(data.error, data.result)

		error: ->
			callback
				error:
					code: '100'
					message: 'Internal error'

	null

for method in ['getTagStream', 'getLinkStream', 'getTagMark', 'getLinkMark', 'getMark', 'getConfig']
	((method) ->
		Traxex[method] = ->
			call.apply(null, [method].concat(Array.prototype.slice.call(arguments)))
	)(method)
