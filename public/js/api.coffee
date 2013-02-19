Traxex = @Traxex

call = (method, options, callback) ->
	options ?= {}
	options.stream = 'traxex'

	$.ajax
		url     : '/_?method=' + method
		type    : 'POST'
		data    : options

		success : (data) ->
			callback(data.error, data.result)

		error   : ->
			callback
				error:
					code    : '100'
					message : 'Internal error'

	null

for method in ['getTagStream', 'getLinkStream', 'getTagMark', 'getLinkMark', 'getMark']
	((method) ->
		Traxex[method] = ->
			call.apply(null, [method].concat(Array.prototype.slice.call(arguments)))
	)(method)
