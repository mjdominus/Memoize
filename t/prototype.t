#!/usr/bin/perl

use lib '..';
use Memoize;
$EXPECTED_WARNING = '(no warning expected)';
print STDERR "$Memoize::Version";


print "1..3\n";

sub q1 ($) { $_[0] + 1 }
sub q2 ()  { time }
sub q3     { join "--", @_ }

$SIG{__WARN__} = \&handle_warnings;

$RES = 'ok';
memoize 'q1';
print "$RES 1\n";

$RES = 'ok';
memoize 'q2';
print "$RES 2\n";

$RES = 'ok';
memoize 'q3';
print "$RES 3\n";

sub handle_warnings {
  $RES = 'not ok' unless $_[0] eq $EXPECTED_WARNING;
}
