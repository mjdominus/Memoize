#!/usr/bin/perl

use lib '..';
use Memoize;


print "1..3\n";

eval { memoize({}) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 1\n");

eval { memoize([]) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 2\n");

eval { my $x; memoize(\$x) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 3\n");

