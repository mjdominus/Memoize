#!/usr/bin/perl

use lib '..';
use Memoize;


print "1..11\n";

eval { memoize({}) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 1\n");

eval { memoize([]) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 2\n");

eval { my $x; memoize(\$x) };
print "\$\@: `$@'\n";
print (($@ ? '' : 'not '), "ok 3\n");

# 4--8
$n = 3;
for $mod (qw(DB_File GDBM_File SDBM_File ODBM_File NDBM_File)) {
  eval { memoize(sub {}, LIST_CACHE => ['TIE', $mod]) };
  print "\$\@: `$@'\n";
  ++$n;
  print (($@ ? '' : 'not '), "ok $n\n");
}

# 9
eval { memoize(sub {}, LIST_CACHE => ['TIE', WuggaWugga]) };
print "\$\@: `$@'\n";
++$n;
print (($@ ? '' : 'not '), "ok $n\n");

# 10
eval { memoize(sub {}, LIST_CACHE => 'YOB GORGLE') };
print "\$\@: `$@'\n";
++$n;
print (($@ ? '' : 'not '), "ok $n\n");

# 11
eval { memoize(sub {}, SCALAR_CACHE => ['YOB GORGLE']) };
print "\$\@: `$@'\n";
++$n;
print (($@ ? '' : 'not '), "ok $n\n");
