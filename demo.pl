#!/usr/bin/perl

use Memoize;
use Benchmark;

$CALLS = 0;
my $a = shift || 20;

sub fibo {
  my ($n) = @_;
  $CALLS++;  
  if ($n < 2) { return $n }
  &fibo($n-1) + &fibo($n-2);
}


$CALLS = 0;
$start = time;
$before = &fibo($a);
$elapsed1 = time - $start;
$CALLS1 = $CALLS;

memoize('fibo');
$CALLS = 0;
$start = time;
$after = &fibo($a);
$elapsed2 = time - $start;
$CALLS2 = $CALLS;

$CALLS = 0;
$start = time;
$after = &fibo($a);
$elapsed3 = time - $start;
$CALLS3 = $CALLS;

print <<EOM;
Unmemoized:            $CALLS1 calls, $elapsed1 sec elapsed
Memoized, first pass:  $CALLS2 calls, $elapsed2 sec elapsed
Memoized, second pass: $CALLS3 calls, $elapsed3 sec elapsed
EOM
