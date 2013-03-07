redis = require('redis')
crypto = require('crypto')
argv = (optimist = require('optimist'))
	.default('port', 8199)
	.default('path', '/auth')
	.default('base', '/')
	.default('cookie', 'vermishel')
	.boolean(['help'])
	.describe
		help    : 'Show help and exit'
		port    : 'Use specified port'
		cookie  : 'Session cookie name'
		path    : 'Request url'
		base    : 'Redirect url'
	.argv

config = require('./vermishel')
redis = redis.createClient(config.server.redis.port, config.server.redis.host)
redis.select(config.server.redis.db)

if argv.help
	optimist.showHelp()
	process.exit()

(Crixalis = require('crixalis'))
	.router
		methods: ['GET']
		async: true
		url: argv.path
	.to ->
		key = config.traxex.auth + String(@params.token).slice(0, 32)
		redis.getset key, '', (error, result) =>
			if error
				@code = 503
			else if result
				secret = crypto.createHash('md5').update(Date.now() + result).digest('hex')
				@cookie
					name: argv.cookie
					domain: config.all.host
					value: secret

				redis.setex(config.server.keys.unique + secret, 86400, result)
				redis.set(config.server.keys.user.data + result, JSON.stringify(id: result, username: result.replace(/@.*$/, ''))

				@redirect(argv.base)
				redis.del(key)
			else
				@code = 403

			@render()

server = require('http')
	.createServer(Crixalis.handler)
	.listen(argv.port)
	.on('close', process.exit)

process.on('SIGINT', server.close.bind(server))
process.title = 'auth [' + argv.port + ']'

Crixalis.view = null
