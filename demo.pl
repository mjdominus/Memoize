
use Memoize;
use Benchmark;

$CALLS = 0;
my $a = shift;

memoize('fibo2');

timethese(100, unmemoized => sub { &
sub fibo1 {
  my ($n) = @_;
  if ($n < 2) { return $n }
  &fibo1($n-1) + &fibo1($n-2);
}

sub fibo2 {
  my ($n) = @_;
  $CALLS++;
  &fibo2($n-1) + &fibo2($n-2);
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

print "($CALLS1, $elapsed1) => ($CALLS2, $elapsed2) => ($CALLS3, $elapsed3)\n";
