
use Memoize;
use Benchmark;

$CALLS = 0;
my $a = shift;

memoize('fibo2');

timethese(100, 
	  { unmemoized => "fibo1($a)",
	    memoized   => "fibo2($a)",
	  });

sub fibo1 {
  my ($n) = @_;
  if ($n < 2) { return $n }
  &fibo1($n-1) + &fibo1($n-2);
}

sub fibo2 {
  my ($n) = @_;
  if ($n < 2) { return $n }
  &fibo2($n-1) + &fibo2($n-2);
}
