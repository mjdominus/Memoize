package Memoize::TEST::JohnObjectPatch;

use strict;
use warnings;

use Test::More tests => 12;

sub new {
    my($pkg, %args) = @_;
    return bless \%args, $pkg;
}

use lib '..';
use Memoize;
memoize('_test_method', SCALAR_CACHE => 'IN_OBJECT', LIST_CACHE => 'IN_OBJECT');
sub _test_method {
    my($object, $arg) = @_;
    
    $object->{invocation_count} ||= 0;
    $object->{invocation_count}++;
    
    return $arg * 2;
}

sub TEST_THIS_BAD_CLASS {
    # Make a simple object
    my $object = __PACKAGE__->new;
    
    # Call a memoized method
    {
        my $value = $object->_test_method(10);
        is($value, 20);
        is($object->{invocation_count}, 1);
    }
    
    # Call again with same arg.  Invocation count should not change
    {
        my $value = $object->_test_method(10);
        is($value, 20);
        is($object->{invocation_count}, 1);
    }
    
    # Call again with different arg
    {
        my $value = $object->_test_method(11);
        is($value, 22);
        is($object->{invocation_count}, 2);
    }
    
    # Now make $object reference a completely different object
    # But still at the same refaddress
    # This simulates situations where an object is destroyed, but another
    # Object is constructed and given same reference address
    
    my $usurper = __PACKAGE__->new;    
    %$object = %$usurper;

    # We should *not* get the memoized value this time
    {
        is($object->{invocation_count}, undef);
        my $value = $object->_test_method(10);
        is($value, 20);
        is($object->{invocation_count}, 1);
    }    
    
    eval {
        my $value = _test_method(11);
    };
    like($@, qr/Method .+_test_method was memoized with /);
    
    # Now check scalar context
    {
        my @value = $object->_test_method(10);
        is_deeply(\@value, [20]);
        # Since it's called in list context
        # Memoize will invoke the actual method again
        # To populate list cache
        is($object->{invocation_count}, 2);
    }    
    
}


&TEST_THIS_BAD_CLASS;

1;