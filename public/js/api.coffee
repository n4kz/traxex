Traxex = @Traxex

call = (method, options, callback) ->
	options ?= {}
	options.stream = 'traxex'

	$.ajax
		url  : '//traxex.n4kz.com/_?method=' + method
		type : 'POST'
		data :  options
	.error ->
		callback
			error:
				code    : '100'
				message : 'Internal error'
	.success (data) ->
		callback(data.error, data.result)

	null

for method in ['getTagStream', 'getLinkStream', 'getTagMark', 'getLinkMark', 'getMark']
	Traxex[method] = call.bind(null, method)
