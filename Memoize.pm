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
# Version 0.06 alpha $Revision: 1.5 $ $Date: 1998/02/23 16:31:22 $

package Memoize;
$VERSION = '0.06';

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

Here's an even simpler example: I wrote a simple ray tracer; the
program would look in a certain direction, figure out what it was
looking at, and then convert the `color' value (typically a string
like `red') of that object to a red, green, and blue pixel value, like
this:

    for ($direction = 0; $direction < 300; $direction++) {
      # Figure out which object is in direction $direction
      $color = $object->{color};
      ($r, $g, $b) = @{&ColorToRGB($color)};
      ...
    }

Since there are relatively few objects in a picture, there are only a
few colors, which get looked up over and over again.  Memoizing
C<ColorToRGB> speeded up the program by several percent.

=head1 DETAILS

This module exports exactly one function, C<memoize>.  The rest of the
functions in this package are None of Your Business.

You should say

	memoize(function)

where C<function> is the name of the function you want to memoize, or
a reference to it.  C<memoize> returns a reference to the new,
memoized version of the function, or C<undef> on a non-fatal error.
At present, there are no non-fatal errors, but there might be some in
the future.

If C<function> was the name of a function, then C<memoize> hides the
old version and installs the new memoized version under the old name,
so that C<&function(...)> actually invokes the memoized version.

=head1 OPTIONS

There are some optional options you can pass to C<memoize> to change
the way it behaves a little.  To supply options, invoke C<memoize>
like this:

	memoize(function, TODISK => filename,
	                  NORMALIZER => function,
			  INSTALL => newname
			 );

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

You would tell C<Memoize> to use this normalizer this way:

	memoize('f', NORMALIZER => 'normalize_f');

C<memoize> knows that if the normalized version of the arguments is
the same for two argument lists, then it can safely look up the value
that it computed for one argument list and return it as the result of
calling the function with the other argmuent list, even if the
argument lists look different.

The default normalizer just concatenates the arguments with C<$;> in
between.  This always works correctly for functions with only one
argument, and also when the arguments never contain C<$;> (which is
normally character #28, control-\.  )  However, it can confuse certain
argument lists:

	normalizer("a\034", "b")
	normalizer("a", "\034b")
	normalizer("a\034\034b")

for example.

The calling context of the function (scalar or list context) is
propagated to the normalizer.  This means that if the memoized
function will treat its arguments differently in list context than it
would in scalar context, you can have the normalizer function select
its behavior based on the results of C<wantarray>.  Even if called in
a list context, a normalizer should still return a single string.

=head2 TODISK

C<TODISK> means that the memo table should be saved to disk so that it
will persist between invocations of your program.  If you use this
option, future runs of your program will get immediate benefit from
the results computed by earlier runs.  A useful use of this feature:
You can construct a batch program that runs in the background and
populates the memo table, and then when you come to run your real
program the memoized function will be screamingly fast because al lits
results have been precomputed.  Or you would be able to do this, if
TODISK were implemented, which it presently isn't.  But it will be.
Some day.  

=head1 OTHER FUNCTION

There's an C<unmemoize> function that you can import if you want to.
If you use it, please let me know what it was good for, since I can
only think of very limited uses for it and was considering leaving it
out altogether.

It accepts a reference to, or the name of a previously memoized
function, and undoes whatever it did to provide the memoized version
in the first place, including making the name refer to the unmemoized
version if appropriate.  It returns a reference to the unmemoized
version of the function.

If you ask it to unmemoize a function that was never memoized, it
croaks.

=head1 CAVEATS

Memoization is not a cure-all:

=over 4

=item *

Do not memoize a function whose behavior depends on program
state other than its own arguments, such as global variables, the time
of day, or file input.  These functions will not produce correct
results when memoized.  For a particularly easy example:

	sub f {
	  time;
	}

This function takes no arguments, and as far as C<Memoize> is
concerned, it always returns the same result.  C<Memoize> is wrong, of
course, and the memoized version of this function will call C<time> once
to get the current time, and it will return that same time
every time you call it after that.

=item *

Do not memoize a function with side effects.

	sub f {
	  my ($a, $b) = @_;
          my $s = $a + $b;
	  print "$a + $b = $s.\n";
	}

This function accepts two arguments, adds them, and prints their sum.
Its return value is the numuber of characters it printed, but you
probably didn't care about that.  But C<Memoize> doesn't understand
that.  If you memoize this function, you will get the result you
expect the first time you ask it to print the sum of 2 and 3, but
subsequent calls will return the number 11 (the return value of
C<print>) without actually printing anything.

=item *

Do not memoize a function that returns a data structure that is
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


=back


=head1 AUTHOR

=begin text
Mark-Jason Dominus (C<mjd-perl-memoize@plover.com>), Plover Systems co.

See the C<Memoize.pm> Page at http://www.plover.com/~mjd/perl/Memoize
for news and upgrades.  
=end text

=begin html
<p>Mark-Jason Dominus (<a href="mailto:mjd-perl-memoize@plover.com"><tt>mjd-perl-memoize@plover.com</tt></a>), Plover Systems co.</p>
<p>See <a href="http://www.plover.com/~mjd/perl/Memoize/">The <tt>Memoize.pm</tt> Page</a> for news and upgrades.</p>

=end html

=cut



#
# Usage memoize(functionname/ref,
#               { TODISK => 1, NORMALIZER => coderef, INSTALL => name }
#

use Carp;
use Exporter;
use vars qw($DEBUG);
@ISA = qw(Exporter);
@EXPORT = qw(memoize);
@EXPORT_OK = qw(unmemoize);
use strict;

my %memotable;
my %revmemotable;
my ($SCALAR, $LIST) = (0, 1);	# Constants

sub memoize {
  my $fn = shift;
  my %options = @_;
  my $options = \%options;
  
  unless (defined($fn) && 
	  (ref $fn eq 'CODE' || ref $fn eq '')) {
    croak "Usage: memoize 'functionname'|coderef {OPTIONS}";
  }

  my $uppack = caller;
  my $cref;			# Code reference to original function
  my $name = (ref $fn ? undef : $fn);

  # Convert function names to code references
  $cref = &_make_cref($fn, $uppack);

  # Goto considered harmful!  Hee hee hee.  
  my $wrapper = eval "sub { unshift \@_, qq{$cref}; goto &_memoizer; }";

  my $install_name;
  if (defined $options->{INSTALL}) {
    # INSTALL => name
    $install_name = $options->{INSTALL};
  } elsif (! exists $options->{INSTALL}) {
    # No INSTALL option provided; use original name if possible
    $install_name = $name;
  } else {
    # INSTALL => undef  means don't install
  }

  if (defined $install_name) {
    $install_name = $uppack . '::' . $install_name
	unless $install_name =~ /::/;
    no strict;
    local($) = 0;	       # ``Subroutine $install_name redefined at ...''
    *{$install_name} = $wrapper; # Install memoized version
  }

  # We should put some more stuff in here eventually.
  $memotable{$cref} = 
  {
    OPTIONS => $options,
    UNMEMOIZED => $cref,
    MEMOIZED => $wrapper,
    PACKAGE => $uppack,
    NAME => $install_name,
    MEMOS => [ { }, { } ],		# Memo tables 
  };

  $revmemotable{$wrapper} = "" . $cref; # Turn code ref into hash key
  
  $wrapper			# Return just memoized version
}

# This is the function that manages the memo tables.
sub _memoizer {
  my $orig = shift;		# stringized version of ref to original func.
  my $info = $memotable{$orig};
  my $normalizer = $info->{OPTIONS}{NORMALIZER} || \&_default_normalizer;
  
  # We should probably do this at memoize time instead of at call time
  unless (ref $normalizer) {
    unless ($normalizer =~ /::/) {
      no strict;
      $normalizer = \&{$info->{PACKAGE} . '::' . $normalizer};
    }
  }

  my $argstr;
  my $context = (wantarray() ? $LIST : $SCALAR);
  { no strict;
    if ($context == $SCALAR) {
      $argstr = &{$normalizer}(@_);
    } elsif ($context == $LIST) {
      ($argstr) = &{$normalizer}(@_);
    } else {
      croak "Internal error \#41; context was neither \$LIST nor \$SCALAR\n";
    }
  }
  if ($context == $SCALAR) {
    if (exists $info->{MEMOS}[$SCALAR]{$argstr}) {
      return $info->{MEMOS}[$SCALAR]{$argstr};
    } else {
      $info->{MEMOS}[$SCALAR]{$argstr} = &{$info->{UNMEMOIZED}}(@_);
    }
  } elsif ($context == $LIST) {
    if (exists $info->{MEMOS}[$LIST]{$argstr}) {
      return @{$info->{MEMOS}[$LIST]{$argstr}};
    } else {
      my $q = $info->{MEMOS}[$LIST]{$argstr} = [&{$info->{UNMEMOIZED}}(@_)];
      @$q;
    }
  } else {
    croak "Internal error \#42; context was neither \$LIST nor \$SCALAR\n";
  }
}

sub _default_normalizer {
  join $;,@_;			# $;,@_;? Perl is great.
}

sub unmemoize {
  my $f = shift;
  my $uppack = caller;
  my $cref = _make_cref($f, $uppack);

  unless (exists $revmemotable{$cref}) {
    croak "Could not unmemoize function `$f', because it was not memoized to begin with";
  }
  
  my $tabent = $memotable{$revmemotable{$cref}};
  unless (defined $tabent) {
    croak "Could not figure out how to unmemoize function `$f'";
  }
  my $name = $tabent->{NAME};
  if (defined $name) {
    no strict;
    *{$name} = $tabent->{UNMEMOIZED}; # Replace with original function
  }
  undef $memotable{$revmemotable{$cref}};
  undef $revmemotable{$cref};
  $tabent->{UNMEMOIZED};
}

sub _make_cref {
  my $fn = shift;
  my $uppack = shift;
  my $cref;
  my $name;

  if (ref $fn eq 'CODE') {
    $cref = $fn;
  } elsif (! ref $fn) {
    if ($fn =~ /::/) {
      $name = $fn;
    } else {
      $name = $uppack . '::' . $fn;
    }
    no strict;
    if (defined $name and !defined(&$name)) {
      croak "Cannot memoize nonexistent function `$fn'";
    }
#    $cref = \&$name;
    $cref = *{$name}{CODE};
  } else {
    my $parent = (caller(1))[3]; # Function that called _make_cref
    croak "Usage: argument 1 to `$parent' must be a function name or reference.\n";
  }
  $DEBUG and warn "${name}($fn) => $cref in _make_cref\n";
  $cref;
}

1;
