#!/usr/bin/perl

use lib '..';
use Memoize;
use Carp;

print "1..2\n";

eval { croak("Ouch.") };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 1\n");

eval { memoize([]) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 2\n");

