all: public/index.html

# Uglifyjs options
UGLIFYOPTS=--compress --mangle

CSS=$(wildcard src/css/*.css)
LIB=$(wildcard src/js/lib/*.js)
SCRIPTS=$(wildcard src/js/*.coffee)

DEBUG=

ifdef DEBUG
UGLIFY=cat
else
UGLIFY=uglifyjs $(UGLIFYOPTS)
endif

public/build.css: $(CSS)
	script/minify.pl $(CSS) > public/build.css

public/build.js: $(LIB) $(SCRIPTS)
	cat $(LIB) > public/build.js
	coffee --compile --lint --print $(SCRIPTS) | $(UGLIFY) >> public/build.js

public/index.html: src/index.html public/build.css public/build.js
	cat src/index.html       > public/index.html
	echo '<style>'          >> public/index.html
	cat public/build.css    >> public/index.html
	echo '</style><script>' >> public/index.html
	cat public/build.js     >> public/index.html
	echo '</script>'        >> public/index.html
	rm -f public/build.js public/build.css
