# -*- mode: perl; perl-indent-level: 2; -*-
# Memoize.pm
#
# Transparent memoization of idempotent functions
#
# Copyright 1998, 1999 M-J. Dominus.
# You may copy and distribute this program under the
# same terms as Perl itself.  If in doubt, 
# write to mjd-perl-memoize+@plover.com for a license.
#
# Version 0.51 beta $Revision: 1.14 $ $Date: 1999/09/17 14:55:57 $

package Memoize;
$VERSION = '0.51';



#
# Usage memoize(functionname/ref,
#               { NORMALIZER => coderef, INSTALL => name,
#                 LIST_CACHE => descriptor, SCALAR_CACHE => descriptor }
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
my @CONTEXT_TAGS = qw(MERGE TIE MEMORY FAULT);
my %IS_CACHE_TAG = map {($_ => 1)} @CONTEXT_TAGS;

# Raise an error if the user tries to specify one of thesepackage as a
# tie for LIST_CACHE

my %scalar_only = map {($_ => 1)} qw(DB_File GDBM_File SDBM_File ODBM_File NDBM_File);

sub memoize {
  my $fn = shift;
  my %options = @_;
  my $options = \%options;
  
  unless (defined($fn) && 
	  (ref $fn eq 'CODE' || ref $fn eq '')) {
    croak "Usage: memoize 'functionname'|coderef {OPTIONS}";
  }

  my $uppack = caller;		# TCL me Elmo!
  my $cref;			# Code reference to original function
  my $name = (ref $fn ? undef : $fn);

  # Convert function names to code references
  $cref = &_make_cref($fn, $uppack);

  # Locate function prototype, if any
  my $proto = prototype $cref;
  if (defined $proto) { $proto = "($proto)" }
  else { $proto = "" }

  # Goto considered harmful!  Hee hee hee.  
  my $wrapper = eval "sub $proto { unshift \@_, qq{$cref}; goto &_memoizer; }";
# --- THREADED PERL COMMENT ---
# The above might not work under threaded perl because goto & semantics are
# broken.  If that's the case, try the following:
#  my $wrapper = eval "sub { &_memoizer(qq{$cref}, \@_); }";
# Confirmed 1998-12-27 this does work.
# 1998-12-29: Sarathy says this bug is fixed in 5.005_54.
# However, the module still fails, although the sample test program doesn't.

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
    local($^W) = 0;	       # ``Subroutine $install_name redefined at ...''
    *{$install_name} = $wrapper; # Install memoized version
  }

  $revmemotable{$wrapper} = "" . $cref; # Turn code ref into hash key

  # These will be the caches!
  my $scalars = {};
  my $lists = {};

  # Now deal with the TODISK options
  {
    my $context;
    foreach $context (qw(SCALAR_CACHE LIST_CACHE)) {
      my $tag = $options{$context};
      next unless defined $tag;
      unless (   ref $tag eq '' 
	      || ref $tag eq 'ARRAY') {
	croak "Argument of $context must be either string, or array ref; aborting";
      }
      $tag = (ref $tag eq 'ARRAY') ? $tag->[0] : $tag;
      unless ($IS_CACHE_TAG{$tag}) {
	croak "Unrecognized option to `$context': `$tag' should be one of (@CONTEXT_TAGS); aborting";
      }
    }

    # Handle `MERGE'
    {
      local($^W) = 0;  # Shut up `uninitialized value' warnings
      my ($so, $lo) = @options{qw(SCALAR_CACHE LIST_CACHE)};
      $so = $so->[0] if ref $so;
      $lo = $lo->[0] if ref $lo;
      
      # Funny thing here that they both mean the same!
      # If there were three contexts, they wouldn't.
      if ($so eq 'MERGE' || $lo eq 'MERGE') {
	$lists = $scalars;	# Alias them together
      } 
    }
    
    foreach $context (qw(SCALAR_CACHE LIST_CACHE)) {
      my $hash = ($context eq 'SCALAR_CACHE') ? $scalars : $lists;
      # If the option wasn't `TIE', this call does nothing.
      _my_tie($context, $hash, $options);  # Croaks on failure
      $options{$context} ||= '';
    }
  }
  
  # We should put some more stuff in here eventually.
  # We've been saying that for serveral versions now.
  # And you know what?  More stuff keeps going in!
  $memotable{$cref} = 
  {
    OPTIONS => $options,
    UNMEMOIZED => $cref,
    MEMOIZED => $wrapper,
    PACKAGE => $uppack,
    NAME => $install_name,
    MEMOS => [ $scalars, $lists ],		# Memo tables 

    # This gets a short name because we check it on every call
    # It says which contexts are forbidden
    X => [map {exists $options{$_} && $options{$_} eq 'FAULT'} 
	  qw(SCALAR_CACHE LIST_CACHE)
	 ],
  };

  $wrapper			# Return just memoized version
}

# This function tries to load a tied hash class and tie the hash to it.
sub _my_tie {
  my ($context, $hash, $options) = @_;
  my $fullopt = $options->{$context};

  # We already checked to make sure that this works.
  my $shortopt = (ref $fullopt) ? $fullopt->[0] : $fullopt;
  
  return unless defined $shortopt && $shortopt eq 'TIE';

  my @args = ref $fullopt ? @$fullopt : ();
  shift @args;
  my $module = shift @args;
  if ($context eq 'LIST_CACHE' && $scalar_only{$module}) {
    croak("You can't use $module for LIST_CACHE because it can only store scalars");
  }
  my $modulefile = $module . '.pm';
  $modulefile =~ s{::}{/}g;
  eval { require $modulefile };
  if ($@) {
    croak "Memoize: Couldn't load hash tie module `$module': $@; aborting";
  }
#  eval  { import $module };
#  if ($@) {
#    croak "Memoize: Couldn't import hash tie module `$module': $@; aborting";
#  }    
#  eval "use $module ()";  
#  if ($@) {
#    croak "Memoize: Couldn't use hash tie module `$module': $@; aborting";
#  }    
  my $rc = (tie %$hash => $module, @args);
  unless ($rc) {
    croak "Memoize: Couldn't tie hash to `$module': $@; aborting";
  }
  1;
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

  # User requested FAULT option?
  if ($info->{X}[$context]) {
    my $funcname = $info->{NAME};
    my $context = $context ? 'list' : 'scalar';
    if (defined $funcname) {
      croak "Function `$funcname' called in forbidden $context context; faulting";
    } else {
      croak "Anonymous function called in forbidden $context context; faulting";
    }
  }

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
      my $val = &{$info->{UNMEMOIZED}}(@_);
      # Scalars are considered to be lists; store appropriately
      if ($info->{OPTIONS}{SCALAR_CACHE} eq 'MERGE') {
	$info->{MEMOS}[$SCALAR]{$argstr} = [$val];
      } else {
	$info->{MEMOS}[$SCALAR]{$argstr} = $val;
      }
      $val;
    }
  } elsif ($context == $LIST) {
    if (exists $info->{MEMOS}[$LIST]{$argstr}) {
      my $val = $info->{MEMOS}[$LIST]{$argstr};
      return ($val) unless ref $val eq 'ARRAY';
      # An array ref is ambiguous. Did the function really return 
      # an array ref?  Or did we cache a list-context list return in
      # an anonymous array?
      # If LISTCONTEXT=>MERGE, then the function never returns lists,
      # so we know for sure:
      return ($val) if $info->{OPTIONS}{LIST_CACHE} eq 'MERGE';
      # Otherwise, we're doomed.  ###BUG
      return @$val;
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
    local($^W) = 0;	       # ``Subroutine $install_name redefined at ...''
    *{$name} = $tabent->{UNMEMOIZED}; # Replace with original function
  }
  undef $memotable{$revmemotable{$cref}};
  undef $revmemotable{$cref};

  # This removes the last reference to the (possibly tied) memo tables
  # my ($old_function, $memotabs) = @{$tabent}{'UNMEMOIZED','MEMOS'};
  # undef $tabent; 

#  # Untie the memo tables if they were tied.
#  my $i;
#  for $i (0,1) {
#    if (tied %{$memotabs->[$i]}) {
#      warn "Untying hash #$i\n";
#      untie %{$memotabs->[$i]};
#    }
#  }

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





=head1 NAME

Memoize - Make your functions faster by trading space for time

=head1 SYNOPSIS

	use Memoize;
	memoize('slow_function');
	slow_function(arguments);    # Is faster than it was before


This is normally all you need to know.  However, many options are available:

	memoize(function, options...);

Options include:

	NORMALIZER => function
	INSTALL => new_name

	SCALAR_CACHE => 'MEMORY'
	SCALAR_CACHE => ['TIE', Module, arguments...]
	SCALAR_CACHE => 'FAULT'
	SCALAR_CACHE => 'MERGE'

	LIST_CACHE => 'MEMORY'
	LIST_CACHE => ['TIE', Module, arguments...]
	LIST_CACHE => 'FAULT'
	LIST_CACHE => 'MERGE'


=head1 DESCRIPTION

`Memoizing' a function makes it faster by trading space for time.  It
does this by caching the return values of the function in a table.
If you call the function again with the same arguments, C<memoize>
jmups in and gives you the value out of the table, instead of letting
the function compute the value all over again.

Here is an extreme example.  Consider the Fibonacci sequence, defined
by the following function:

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

This function is a good candidate for memoization.  If you memoize the
`fib' function above, it will compute fib(14) exactly once, the first
time it needs to, and then save the result in a table.  Then if you
ask for fib(14) again, it gives you the result out of the table.
While computing fib(14), instead of computing fib(12) twice, it does
it once; the second time it needs the value it gets it from the table.
It doesn't compute fib(11) four times; it computes it once, getting it
from the table the next three times.  Instead of making 1,200
recursive calls to `fib', it makes 15.  This makes the function about
150 times faster.

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

	memoize(function, NORMALIZER => function,
			  INSTALL => newname,
                          SCALAR_CACHE => option,
	                  LIST_CACHE => option
			 );

Each of these options is optional; you can include some, all, or none
of them.

=head2 INSTALL

If you supply a function name with C<INSTALL>, memoize will install
the new, memoized version of the function under the name you give.
For example, 

	memoize('fib', INSTALL => 'fastfib')

installs the memoized version of C<fib> as C<fastfib>; without the
C<INSTALL> option it would have replaced the old C<fib> with the
memoized version.  

To prevent C<memoize> from installing the memoized version anywhere, use
C<INSTALL =E<gt> undef>.

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
calling the function with the other argument list, even if the
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

=head2 C<SCALAR_CACHE>, C<LIST_CACHE>

Normally, C<Memoize> caches your function's return values into an
ordinary Perl hash variable.  However, you might like to have the
values cached on the disk, so that they persist from one run of your
program to the next, or you might like to associate some other
interesting semantics with the cached values.  

There's a slight complication under the hood of C<Memoize>: There are
actually I<two> caches, one for scalar values and one for list values.
When your function is called in scalar context, its return value is
cached in one hash, and when your function is called in list context,
its value is cached in the other hash.  You can control the caching
behavior of both contexts independently with these options.

The argument to C<LIST_CACHE> or C<SCALAR_CACHE> must either be one of
the following four strings:

	MEMORY
	TIE
	FAULT
	MERGE

or else it must be a reference to a list whose first element is one of
these four strings, such as C<[TIE, arguments...]>.

=over 4

=item C<MEMORY>

C<MEMORY> means that return values from the function will be cached in
an ordinary Perl hash variable.  The hash variable will not persist
after the program exits.  This is the default.

=item C<TIE>

C<TIE> means that the function's return values will be cached in a
tied hash.  A tied hash can have any semantics at all.  It is
typically tied to an on-disk database, so that cached values are
stored in the database and retrieved from it again when needed, and
the disk file typically persists after your pogram has exited.  

If C<TIE> is specified as the first element of a list, the remaining
list elements are taken as arguments to the C<tie> call that sets up
the tied hash.  For example,

	SCALAR_CACHE => [TIE, DB_File, $filename, O_RDWR | O_CREAT, 0666]

says to tie the hash into the C<DB_File> package, and to pass the
C<$filename>, C<O_RDWR | O_CREAT>, and C<0666> arguments to the C<tie>
call.  This has the effect of storing the cache in a C<DB_File>
database whose name is in C<$filename>.

Other typical uses of C<TIE>:

	LIST_CACHE => [TIE, GDBM_File, $filename, O_RDWR | O_CREAT, 0666]
	SCALAR_CACHE => [TIE, MLDBM, DB_File, $filename, O_RDWR|O_CREAT, 0666]
	LIST_CACHE => [TIE, My_Package, $tablename, $key_field, $val_field]

This last might tie the cache hash to a package that you wrote
yourself that stores the cache in a SQL-accessible database.
A useful use of this feature: You can construct a batch program that
runs in the background and populates the memo table, and then when you
come to run your real program the memoized function will be
screamingly fast because all its results have been precomputed. 

=item C<FAULT>

C<FAULT> means that you never expect to call the function in scalar
(or list) context, and that if C<Memoize> detects such a call, it
should abort the program.  The error message is one of

	`foo' function called in forbidden list context at line ...
	`foo' function called in forbidden scalar context at line ...

=item C<MERGE>

C<MERGE> normally means the function does not distinguish between list
and sclar context, and that return values in both contexts should be
stored together.  C<LIST_CACHE =E<gt> MERGE> means that list context
return values should be stored in the same hash that is used for
scalar context returns, and C<SCALAR_CACHE =E<gt> MERGE> means the
same, mutatis mutandis.  It is an error to specify C<MERGE> for both,
but it probably does something useful.

Consider this function:

	sub pi { 3; }

Normally, the following code will result in two calls to C<pi>:

    $x = pi();
    ($y) = pi();
    $z = pi();

The first call caches the value C<3> in the scalar cache; the second
caches the list C<(3)> in the list cache.  The third call doesn't call
the real C<pi> function; it gets the value from the scalar cache.

Obviously, the second call to C<pi> is a waste of time, and storing
its return value is a waste of space.  Specifying C<LIST_CACHE
=E<gt> MERGE> will make C<memoize> use the same cache for scalar and
list context return values, so that the second call uses the scalar
cache that was populated by the first call.  C<pi> ends up being
cvalled only once, and both subsequent calls return C<3> from the
cache, regardless of the calling context.

Another use for C<MERGE> is when you want both kinds of return values
stored in the same disk file; this saves you from having to deal with
two disk files instead of one.  You can use a normalizer function to
keep the two sets of return values separate.  For example:

	memoize 'myfunc',
	  NORMALIZER => 'n',
	  SCALAR_CACHE => [TIE, MLDBM, DB_File, $filename, ...],
	  LIST_CACHE => MERGE,
	;

	sub n {
	  my $context = wantarray() ? 'L' : 'S';
	  # ... now compute the hash key from the arguments ...
	  $hashkey = "$context:$hashkey";
	}

This normalizer function will store scalar context return values in
the disk file under keys that begin with C<S:>, and list context
return values under keys that begin with C<L:>.

=back

=head1 OTHER FUNCTION

There's an C<unmemoize> function that you can import if you want to.
Why would you want to?  Here's an example: Suppose you have your cache
tied to a DBM file, and you want to make sure that the cache is
written out to disk if someone interrupts the program.  If the program
exits normally, this will happen anyway, but if someone types
control-C or something then the program will terminate immediately
without syncronizing the database.  So what you can do instead is

    $SIG{INT} = sub { unmemoize 'function' };


Thanks to Jonathan Roy for discovering a use for C<unmemoize>.

C<unmemoize> accepts a reference to, or the name of a previously
memoized function, and undoes whatever it did to provide the memoized
version in the first place, including making the name refer to the
unmemoized version if appropriate.  It returns a reference to the
unmemoized version of the function.

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

=head1 PERSISTENT CACHE SUPPORT

You can tie the cache tables to any sort of tied hash that you want
to, as long as it supports C<TIEHASH>, C<FETCH>, C<STORE>, and
C<EXISTS>.  For example,

	memoize 'function', SCALAR_CACHE => 
                            [TIE, GDBM_File, $filename, O_RDWR|O_CREAT, 0666];

works just fine.  For some storage methods, you need a little glue.

C<SDBM_File> doesn't supply an C<EXISTS> method, so included in this
package is a glue module called C<Memoize::SDBM_File> which does
provide one.  Use this instead of plain C<SDBM_File> to store your
cache table on disk in an C<SDBM_File> database:

	memoize 'function', 
                SCALAR_CACHE => 
                [TIE, Memoize::SDBM_File, $filename, O_RDWR|O_CREAT, 0666];

C<NDBM_File> has the same problem and the same solution.

C<Storable> isn't a tied hash class at all.  You can use it to store a
hash to disk and retrieve it again, but you can't modify the hash while
it's on the disk.  So if you want to store your cache table in a
C<Storable> database, use C<Memoize::Storable>, which puts a hashlike
front-end onto C<Storable>.  The hash table is actually kept in
memory, and is loaded from your C<Storable> file at the time you
memoize the function, and stored back at the time you unmemoize the
function (or when your program exits):

	memoize 'function', 
                SCALAR_CACHE => [TIE, Memoize::Storable, $filename];

	memoize 'function', 
                SCALAR_CACHE => [TIE, Memoize::Storable, $filename, 'nstore'];

Include the `nstore' option to have the C<Storable> database written
in `network order'.  (See L<Storable> for more details about this.)

=head1 EXPIRATION SUPPORT

See Memoize::Expire, which is a plug-in module that adds expiration
functionality to Memoize.  If you don't like the kinds of policies
that Memoize::Expire implements, it is easy to write your own plug-in
module to implement whatever policy you desire.

=head1 BUGS

Needs a better test suite, especially for the tied and expiration stuff.

Also, there is some problem with the way C<goto &f> works under
threaded Perl, because of the lexical scoping of C<@_>.  This is a bug
in Perl, and until it is resolved, Memoize won't work with these
Perls.  To fix it, you need to chop the source code a little.  Find
the comment in the source code that says C<--- THREADED PERL
COMMENT---> and comment out the active line and uncomment the
commented one.  Then try it again.

I wish I could investigate this threaded Perl problem.  If someone
could lend me an account on a machine with threaded Perl for a few
hours, it would be very helpful.

That is why the version number is 0.51 instead of 1.00.

Here's a bug that isn't my fault: Some versions of C<DB_File> won't
let you store data under a key of length 0.  That means that if you
have a function C<f> which you memoized and the cache is in a
C<DB_File> database, then the value of C<f()> (C<f> called with no
arguments) will not be memoized.  Let us all breathe deeply and repeat
this mantra: ``Gosh, Keith, that sure was a stupid thing to do.''

=head1 MAILING LIST

To join a very low-traffic mailing list for announcements about
C<Memoize>, send an empty note to C<mjd-perl-memoize-request@plover.com>.

=head1 AUTHOR

Mark-Jason Dominus (C<mjd-perl-memoize+@plover.com>), Plover Systems co.

See the C<Memoize.pm> Page at http://www.plover.com/~mjd/perl/Memoize/
for news and upgrades.  Near this page, at
http://www.plover.com/~mjd/perl/MiniMemoize/ there is an article about
memoization and about the internals of Memoize that appeared in The
Perl Journal, issue #13.  (This article is also included in the
Memoize distribution as `article.html'.)

To join a mailing list for announcements about C<Memoize>, send an
empty message to C<mjd-perl-memoize-request@plover.com>.  This mailing
list is for announcements only and has extremely low traffic---about
four messages per year.

=head1 THANK YOU

Many thanks to Jonathan Roy for bug reports and suggestions, to
Michael Schwern for other bug reports and patches, to Mike Cariaso for
helping me to figure out the Right Thing to Do About Expiration, to
Joshua Gerth, Joshua Chamas, Jonathan Roy, Mark D. Anderson, and
Andrew Johnson for more suggestions about expiration, to Ariel
Scolnikov for delightful messages about the Fibonacci function, to
Dion Almaer for thought-provoking suggestions about the default
normalizer, to Walt Mankowski and Kurt Starsinic for much help
investigating problems under threaded Perl, to Alex Dudkevich for
reporting the bug in prototyped functions and for checking my patch,
to Tony Bass for many helpful suggestions, to Philippe Verdret for
enlightening discussion of Hook::PrePostCall, to Nat Torkington for
advice I ignored, to Chris Nandor for portability advice, and to Jenda
Krynicky for being a light in the world.

=cut

