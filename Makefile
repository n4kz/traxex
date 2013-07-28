all: public/index.html

UGLIFYOPTS=--compress --mangle

public/build.css: src/css/*.css
	script/minify.pl $^ > public/build.css

libs: src/js/lib/*.js
	cat $^ > public/build.js

coffee: src/js/*.coffee
	coffee --compile $^
	cat $(foreach file, $^, $(subst .coffee,.js,$(file))) | uglifyjs $(UGLIFYOPTS) >> public/build.js

public/build.js: libs coffee

public/index.html: src/index.html public/build.css public/build.js
	cat src/index.html       > public/index.html
	echo '<style>'          >> public/index.html
	cat public/build.css    >> public/index.html
	echo '</style><script>' >> public/index.html
	cat public/build.js     >> public/index.html
	echo '</script>'        >> public/index.html
	rm -f public/build.js public/build.css
