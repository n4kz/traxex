all:
	coffee --compile --lint src/js/*.coffee
	uglifyjs src/js/lib/zepto.js >> public/build.js
	uglifyjs src/js/main.js      >> public/build.js
	uglifyjs src/js/api.js       >> public/build.js
	uglifyjs src/js/model.js     >> public/build.js
	uglifyjs src/js/view.js      >> public/build.js
	script/minify.pl src/s/normalize.css src/s/main.css > public/build.css
	echo `cat src/index.html` | sed 's/> </></g' > public/index.html
	echo -n '<style>'          >> public/index.html
	cat public/build.css       >> public/index.html
	echo -n '</style><script>' >> public/index.html
	cat public/build.js        >> public/index.html
	echo    '</script>'        >> public/index.html
	rm public/build.*

clean:
	rm -rf src/js/*.js
