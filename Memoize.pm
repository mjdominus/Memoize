# -*- mode: perl; perl-indent-level: 2; 
# Memoize.pm
#
# Transparent memoization of idempotent functions
#
# Copyright 1998 M-J. Dominus.
# You may copy and distribute this program under the
# same terms as Perl iteself.  If in doubt, write to mjd@pobox.com
# for a license.
#
# Version 0.02 alpha $Revision: 1.2 $ $Date: 1998/02/04 22:04:03 $

package Memoize;
$VERSION = '0.02';

=head1 NAME

Memoize - Make your functions faster by trading space for time

=head1 SYNOPSIS

 use Memoize;
 memoize('slow_function');
 slow_function(arguments);    # Is faster than it was before

=head1 DESCRIPTION

`Memoizing' a function makes it faster by trading space for time.
Here is an example.  Consider the Fibonacci sequence, defined by the
following function:

	# Compute Fibonacci numbers
	sub fib {
	  my $n = shift;
	  return $n if $n < 2;
	  fib($n-1) + fib($n-2);
	}

This function is very slow.  Why?  To compute fib(14), it first wants
to compute fib(13) and fib(12), and add the results.  But to compute
fib(13), it first has to compute fib(12) and fib(11), and then it
comes back and computes fib(12) all over again even though the answer
is the same.  And both of the times that it wants to compute fib(12),
it has to compute fib(11) from scratch, and then it has to do it
again each time it wants to compute fib(13).  This function does so
much recomputing of old results that it takes a really long time to
run---fib(14) makes 1,200 extra recursive calls to itself, to compute
and recompute things that it already computed.

This function is a good candidate for memoization.  Whenever a
memoized function computes a result, it saves the result in a table.
Then, if you ask the function to do the same work later, it just gives
you the answer that was in the table, instead of computing it all over
again.

This module will automatically memoize functions for you.  For
example, if you memoize the `fib' function above, it will compute
fib(14) exactly once, the first time it needs to, and then save the
result in a table.  Then if you ask for fib(14) again, it gives you
the result out of the table.  While computing fib(14), instead of
computing fib(12) twice, it does it once; the second time it needs
the value it gets it from the table.  It doesn't compute fib(11) four
times; it computes it once, getting it from the table the next three
times.  Instead of making 1,200 recursive calls to `fib', it makes
15.  This makes the function about 150 times faster.

You could do the memoization yourself, by rewriting the function, like
this:

	# Compute Fibonacci numbers, memoized version
	{ my @fib;
  	  sub fib {
	    my $n = shift;
	    return $fib[$n] if defined $fib[$n];
	    return $fib[$n] = $n if $n < 2;
	    $fib[$n] = fib($n-1) + fib($n-2);
	  }
        }

Or you could use this module, like this:

	use Memoize;
	memoize('fib');

	# Rest of the fib function just like the original version.

This makes it easy to turn memoizing on and off.

=head1 DETAILS

This module exports exactly one function, C<memoize>.  The rest of the
functions in this package are None of Your Business.

You should say

	memoize(function)

where C<function> is the name of the function you want to memoize, or
a reference to it.  C<memoize> returns a reference to the new,
memoized version of the function.

If C<function> was the name of a function, then C<memoize> hides the
old version and installs the new memoized version under the old name,
so that C<&function(...)> actually invokes the memoized version.

=head1 OPTIONS

There are some optional options you can pass to C<memoize> to change
the way it behaves a little.  To supply options, invokdle C<memoize>
like this:

	memoize(function, { TODISK => filename,
	                    NORMALIZER => function,
			    INSTALL => newname
			  });

Each of these three options is optional; you can include some, all, or
none of them.

=head2 INSTALL

If you supply a function name with C<INSTALL>, memoize will install
the new, memoized version of the function under the name you give.
For example, 

	memoize('fib', INSTALL => 'fastfib')

installs the memoized version of C<fib> as C<fastfib>; without the
C<INSTALL> option it would have replaced the old C<fib> with the
memoized version.  

=head2 NORMALIZER

Suppose your function looks like this:

	# Typical call: f('aha!', A => 11, B => 12);
	sub f {
	  my $a = shift;
	  my %hash = @_;
	  $hash{B} ||= 2;  # B defaults to 2
	  $hash{C} ||= 7;  # C defaults to 7

	  # Do something with $a, %hash
	}

Now, the following calls to your function are all completely equivalent:

	f(OUCH);
	f(OUCH, B => 2);
	f(OUCH, C => 7);
	f(OUCH, B => 2, C => 7);
	f(OUCH, C => 7, B => 2);
	(etc.)

However, unless you tell C<Memoize> that these calls are equivalent,
it will not know that, and it will compute the values for these
invocations of your function separately, and store them separately.

To prevent this, supply a C<NORMALIZER> function that turns the
program arguments into a string in a way that equivalent arguments
turn into the same string.  A C<NORMALIZER> function for C<f> above
might look like this:

	sub normalize_f {
	  my $a = shift;
	  my %hash = @_;
	  $hash{B} ||= 2;
	  $hash{C} ||= 7;

	  join($;, $a, map ($_ => $hash{$_}) sort keys %hash);
	}

Each of the argument lists above comes out of the C<normalize_f>
function looking exactly the same, like this:

	OUCH^\B^\2^\C^\7

C<memoize> knows that if the normalized version of the arguments is
the same for two argument lists, then it can safely look up the value
that it computed for one argument list and return it as the result of
calling the function with the other argmuent list, even if the
argument lists look different.

=head2 TODISK

C<TODISK> means that the memo table should be saved to disk so that it
will persist between invokations of your program.  If you use this
option, future runs of your program will get immediate benefit from
the results computed by earlier runs.  A useful use of this feature:
You can construct a batch program that runs in the background and
populates the memo table, and then when you come to run your real
program the memoized function will be screamingly fast because al lits
results have been precomputed.  Or you would be able to do this, if
TODISK were implemented, which it presently isn't.  But it will be.
Some day.  

=head1 CAVEATS

Memoization is not a cure-all:

=item Do not memoize a function whose behavior depends on program
state other than its own arguments, such as global variables, the time
of day, or file input.  These functions whill not produce correct
results when memoized.  For a particularly easy example:

	sub f {
	  my $i = <STDIN>;
	  chomp $i;	
	  $i;
	}

This function takes no arguments, and as far as C<Memoize> is
concerned, it always returns the same result.  C<Memoize> is wrong, of
course, and the memoized version of this function will read STDIN once
to get a string from the user, and it will return that same string
every time you call it after that.

=item Do not memoize a function with side effects.

	sub f {
	  my ($a, $b) = @_;
          my $s = $a + $b;
	  print "$a + $b = $s.\n";
	}

This function accepts two arguments, adds them, and prints their sum.
Its return value is the numuber of characters it printed, but you
probably didn't care abuot that.  But C<Memoize> doesn't understand
that.  If you memoize this function, you will get the result you
expect the first time you ask it to prnit the sum of 2 and 3, but
subsequent calls will return the number 11 (the return value of
C<print>) without actually printing anything.

=item Do not memoize a function that returns a data structure that is
modified by its caller.

Consider these functions:  C<getusers> returns a list of users somehow,
and then C<main> throws away the first user on the list and prints the
rest:

	sub main {
	  my $userlist = getusers();
	  shift @$userlist;
	  foreach $u (@$userlist) {
	    print "User $u\n";
	  }
	}

	sub getusers {
	  my @users;
	  # Do something to get a list of users;
	  \@users;  # Return reference to list.
	}

If you memoize C<getusers> here, it will work right exactly once.  The
reference to the users list will be stored in the memo table.  C<main>
will discard the first element from the referenced list.  The next
time you invoke C<main>, C<Memoize> will not call C<getusers>; it will
just return the same reference to the same list it got last time.  But
this time the list has already had its head removed; C<main> will
erroneously remove another element from it.  The list will get shorter
and shorter every time you call C<main>.

=head1 TO DO

=over 4

=item There should be an C<unmemoize> function.

=item We should extend the benchmarking module to allow

	timethis(main, MEMOIZED => [ suba, subb ])

What would this do?  It would time C<main> three times, once with
C<suba> and C<subb> unmemoized, twice with them memoized.

Why would you want to do this?  By the third set of runs, the memo
tables would be fully populated, so all calls by C<main> to C<suba>
and C<subb> wuold return immediately.  You would be able to see how
much of C<main>'s running time was due to time spent computing in
C<suba> and C<subb>.  If that was just a little time, you would know
that optimizing or improving C<suba> and C<subb> would not have a
large effect on the performance of C<main>.  But if there was a big
difference, you would know that C<suba> or C<subb> was a good
candidate for optimization if you needed to make C<main> go faster.

=item There was some other stuff, but I forget.

=item Maybe a tied-hash interface to the memo-table, which a hook to
      automatically populate an entry if no value is there yet?

=back

=cut



#
# Usage memoize(functionname/ref,
#               { TODISK => 1, NORMALIZER => coderef, INSTALL => name }
#

use Carp;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(memoize);

my %memotable;

sub memoize {
  my $fn = shift;
  my $options = shift || {};
  
  unless (defined($fn)) {
    croak "Usage: memoize functionname|coderef {OPTIONS}\n";
  }

  my $uppack = caller;
  my $cref;			# Code reference to original function

  if (ref $fn eq CODE) {
    $cref = $fn;
  } elsif (! ref $fn) {
    if ($fn =~ /::/) {
      $name = $fn;
    } else {
      $name = $uppack . '::' . $fn;
    }
    $cref = *{$name}{CODE}; # Magic
  } else {
    croak "Usage: argument 1 to `memoize' must be a function name or reference.\n";
  }

  # Goto considered harmful!  Hee hee hee.  
  my $wrapper = eval "sub { unshift \@_, qq{$cref}; goto &_memoizer; }";

  # We should put some more stuff in here eventually.
  $memotable{$cref} = 
  {
    OPTIONS => $options,
    UNMEMOIZED => $cref,
    MEMOIZED => $wrapper,
    PACKAGE => $uppack,
    NAME => undef,		# What was this supposed to be for?
    MEMOS => { },		# Memo table
  };
  
  $install_name = $options{INSTALL} || $name;
  if (defined $install_name) {
    $install_name = $uppack . '::' . $install_name
	unless $install_name =~ /::/;
    *{$install_name} = $wrapper; # Install memoized version
  }
  
  $cref;			# Return memoized version
}

# This is the function that manages the memo tables.
sub _memoizer {
  my $orig = shift;		# stringized version of ref to original func.
  my $info = $memotable{$orig};
  my $normalizer = $info->{OPTIONS}{NORMALIZER} || \&_default_normalizer;
  
  # We should probably do this at memoize time instead of at call time
  unless (ref $normalizer) {
    unless ($normalizer =~ /::/) {
      $normalizer = *{$info->{PACKAGE} . '::' . $normalizer}{CODE};
    }
  }

  my $argstr = &{$normalizer}(@_);
  if (exists $info->{MEMOS}{$argstr}) {
    return $info->{MEMOS}{$argstr};
  } 

  $info->{MEMOS}{$argstr} = &{$info->{UNMEMOIZED}}(@_);
}

sub _default_normalizer {
  join $;,@_;			# $;,@_;? Perl is great.
}

1;
