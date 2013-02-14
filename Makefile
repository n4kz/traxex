all:
	coffee --compile public/js/*.coffee
	uglifyjs public/js/lib/es5-shim.js     >> public/js/build.js
	uglifyjs public/js/lib/jquery-1.9.1.js >> public/js/build.js
	uglifyjs public/js/main.js             >> public/js/build.js
	uglifyjs public/js/api.js              >> public/js/build.js
	uglifyjs public/js/model.js            >> public/js/build.js
	uglifyjs public/js/view.js             >> public/js/build.js
	mv public/js/build.js public/js/traxex.js
	cat public/s/normalize.css public/s/main.css > public/s/traxex.css

clean:
	rm -rf public/js/*.js
