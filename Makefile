# Uglifyjs options
UGLIFY=--compress --mangle

all:
	coffee --compile --lint src/js/*.coffee
	uglifyjs src/js/lib/gator.js $(UGLIFY) >> public/build.js
	cat src/js/lib/ulfsaar.min.js          >> public/build.js
	uglifyjs src/js/main.js      $(UGLIFY) >> public/build.js
	uglifyjs src/js/api.js       $(UGLIFY) >> public/build.js
	uglifyjs src/js/model.js     $(UGLIFY) >> public/build.js
	cat src/js/view.js | sed 's/\\n\t*//g'| uglifyjs $(UGLIFY) >> public/build.js
	script/minify.pl src/s/normalize.css src/s/main.css > public/build.css
	echo -n `cat src/index.html` | sed 's/> </></g' > public/index.html
	echo -n '<style>'          >> public/index.html
	cat public/build.css       >> public/index.html
	echo -n '</style><script>' >> public/index.html
	cat public/build.js        >> public/index.html
	echo    '</script>'        >> public/index.html
	rm public/build.*

clean:
	rm -rf src/js/*.js
