#!/usr/bin/env perl
use strict;
local $/;

print grep {
	# Remove comments
	s{/\*.*?\*/} {\n}gs;

	# Remove redundant spacing
	s{[\s\t\n\r]+} { }g;

	# Remove unnecessary spacing
	s{(?<=[:;\{\},]) (?!\.)} {}g;

	1;
} readline;
