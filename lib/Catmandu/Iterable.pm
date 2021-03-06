package Catmandu::Iterable;

use namespace::clean;
use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
use Time::HiRes qw(gettimeofday tv_interval);
require Catmandu::Iterator;
require Catmandu::ArrayIterator;
use Role::Tiny;

requires 'generator';

sub to_array {
    my ($self) = @_;
    my $next = $self->generator;
    my @a;
    my $data;
    while (defined($data = $next->())) {
        push @a, $data;
    }
    \@a;
}

sub count {
    my ($self) = @_;
    my $next = $self->generator;
    my $n = 0;
    while ($next->()) {
        $n++;
    }
    $n;
}

sub slice {
    my ($self, $start, $total) = @_;
    $start //= 0;
    Catmandu::Iterator->new(sub { sub {
        if (defined $total) {
            $total || return;
        }
        state $next = $self->generator;
        state $data;
        while (defined($data = $next->())) {
            if ($start > 0) {
                $start--;
                next;
            }
            if (defined $total) {
                $total--;
            }
            return $data;
        }
        return;
    }});
}

sub each {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $n = 0;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data);
        $n++;
    }
    $n;
}

sub tap {
    my ($self, $sub) = @_;
    Catmandu::Iterator->new(sub { sub {
        state $next = $self->generator;
        state $data;
        if (defined($data = $next->())) {
            $sub->($data);
            return $data;
        }
        return;
    }});
}

sub any {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) && return 1;
    }
    return 0;
}

sub many {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $n = 0;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) && ++$n > 1 && return 1;
    }
    return 0;
}

sub all {
    my ($self, $sub) = @_;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        $sub->($data) || return 0;
    }
    return 1;
}

sub map {
    my ($self, $sub) = @_;
    Catmandu::Iterator->new(sub { sub {
        state $next = $self->generator;
        $sub->($next->() // return);
    }});
}

sub reduce {
    my $self = shift;
    my $memo_set = @_ > 1;
    my $sub  = pop;
    my $memo = shift;
    my $next = $self->generator;
    my $data;
    while (defined($data = $next->())) {
        if ($memo_set) {
            $memo = $sub->($memo, $data);
        } else {
            $memo = $data;
            $memo_set = 1;
        }
    }
    $memo;
}

sub first {
    $_[0]->generator->();
}

sub rest {
    $_[0]->slice(1);
}

sub take {
    $_[0]->slice(0, $_[1]);
}

{
    my $to_sub = sub {
        my ($arg1, $arg2) = @_;

        if (is_string($arg1)) {
            if (is_regex_ref($arg2)) {
                return sub {
                    is_hash_ref($_[0]) || return 0;
                    my $val = $_[0]->{$arg1}; is_value($val) && $val =~ $arg2;
                };
            }
            if (is_array_ref($arg2)) {
                return sub {
                    is_hash_ref($_[0]) || return 0;
                    is_value(my $val = $_[0]->{$arg1}) || return 0;
                    for my $v (@$arg2) {
                        return 1 if $val eq $v;
                    }
                    0;
                };
            }
            return sub {
                is_hash_ref($_[0]) || return 0;
                my $val = $_[0]->{$arg1}; is_value($val) && $val eq $arg2;
            };
        }

        if (is_regex_ref($arg1)) {
            return sub {
                my $val = $_[0]; is_value($val) && $val =~ $arg1;
            };
        }

        $arg1;
    };

    sub detect {
        my $self = shift; my $sub = $to_sub->(@_);
        my $next = $self->generator;
        my $data;
        while (defined($data = $next->())) {
            $sub->($data) && return $data;
        }
        return;
    }

    sub select {
        my $self = shift; my $sub = $to_sub->(@_);
        Catmandu::Iterator->new(sub { sub {
            state $next = $self->generator;
            state $data;
            while (defined($data = $next->())) {
                $sub->($data) && return $data;
            }
            return;
        }});
    }

    sub reject {
        my $self = shift; my $sub = $to_sub->(@_);
        Catmandu::Iterator->new(sub { sub {
            state $next = $self->generator;
            state $data;
            while (defined($data = $next->())) {
                $sub->($data) || return $data;
            }
            return;
        }});
    }
};

sub pluck {
    my ($self, $key) = @_;
    $self->map(sub {
        $_[0]->{$key};
    });
}

sub invoke {
    my ($self, $method, @args) = @_;
    $self->map(sub {
        $_[0]->$method(@args);
    });
}

sub contains { goto &includes }

sub includes {
    my ($self, $data) = @_;
    $self->any(sub {
        is_same($data, $_[0]);
    });
}

sub group {
    my ($self, $size) = @_;
    Catmandu::Iterator->new(sub { sub {
        state $next = $self->generator;

        my $group = [];

        for (my $i = 0; $i < $size; $i++) {
            push @$group, $next->() // last;
        }

        unless (@$group) {
            return;
        }

        Catmandu::ArrayIterator->new($group);
    }});
}

sub interleave {
    my @iterators = @_;
    Catmandu::Iterator->new(sub { sub {
        state @generators;
        state $n = @iterators;
        state $i = 0;
        while ($n) {
            $i = 0 if $i == $n;
            my $next = $generators[$i] ||= $iterators[$i]->generator;
            if (defined(my $data = $next->())) {
                $i++;
                return $data;
            } else {
                splice @generators, $i, 1;
                $n--;
            }
        }
        return;
    }});
}

sub max {
    $_[0]->reduce(undef, sub {
        my ($memo, $data) = @_;
        return $data > $memo ? $data : $memo if is_number($memo) && is_number($data);
        return $memo if is_number($memo);
        return $data if is_number($data);
        return;
    });
}

sub min {
    $_[0]->reduce(undef, sub {
        my ($memo, $data) = @_;
        return $data < $memo ? $data : $memo if is_number($memo) && is_number($data);
        return $memo if is_number($memo);
        return $data if is_number($data);
        return;
    });
}

sub benchmark {
    my ($self) = @_;
    $self->tap(sub {
        state $n = 0;
        state $t = [gettimeofday];
        if (++$n % 100 == 0) {
            printf STDERR "added %9d (%d/sec)\n", $n, $n/tv_interval($t);
        }
    });
}

1;

=head1 NAME

Catmandu::Iterable - Base class for all iterable Catmandu classes

=head1 SYNOPSIS

    # Create an example Iterable using the Catmandu::Importer::Mock class
    my $it = Catmandu::Importer::Mock->new(size => 10);

    my $array_ref = $it->to_array;
    my $num       = $it->count;

    # Loop functions
    $it->each(sub { print shift->{n} });

    my $item = $it->first;

    $it->rest
       ->each(sub { print shift->{n} });

    $it->slice(3,2)
       ->each(sub { print shift->{n} });

    $it->take(5)
       ->each(sub { print shift->{n} });

    $it->group(5)
       ->each(sub { printf "group of %d items\n" , shift->count});

    $it->tap(\&logme)->tap(\&printme)->tap(\&mailme)
       ->each(sub { print shift->{n} });

    # Select and loop
    my $item = $it->detect(sub { shift->{n} > 5 });

    $it->select(sub { shift->{n} > 5})
       ->each(sub { print shift->{n} });

    $it->reject(sub { shift->{n} > 5})
       ->each(sub { print shift->{n} });

    # Boolean
    if ($it->any(sub { shift->{n} > 5}) {
	 .. at least one n > 5 ..
    }

    if ($it->many(sub { shift->{n} > 5}) {
	 .. at least two n > 5 ..
    }

    if ($it->all(sub { shift->{n} > 5}) {
	 .. all n > 5 ..
    }

    # Modify and summary
    my $it2 = $it->map(sub { shift->{n} * 2 });

    my $sum = $it2->reduce(0,sub {
		my ($prev,$this) = @_;
		$prev + $this;
		});

    my $it3 = $it->group(2)->invoke('to_array');

=head1 DESCRIPTION

The Catmandu::Iterable class provides many list methods to Iterators such as Importers and
Exporters. Most of the methods are lazy if the underlying datastream supports it. Beware of
idempotence: many iterators contain state information and calls will give different results on
a second invocation.

=head1 METHODS

=head2 to_array

Return all the items in the Iterator as an ARRAY ref.

=head2 count

Return the count of all the items in the Iterator.

=head3 LOOPING

=head2 each(\&callback)

For each item in the Iterator execute the callback function with the item as first argument. Returns
the number of items in the Iterator.

=head2 first

Return the first item from the Iterator.

=head2 rest

Returns an Iterator containing everything except the first item.

=head2 slice(INDEX,LENGTH)

Returns an Iterator starting at the item at INDEX returning at most LENGTH results.

=head2 take(NUM)

Returns an Iterator with the first NUM results.

=head2 group(NUM)

Splitting the Iterator into NUM parts and returning an Iterator for each part.

=head2 interleave(@iterators)

Returns an Iterator which returns the first item of each iterator then the
second of each and so on.

=head2 contains($data)

Alias for C<includes>.

=head2 includes($data)

return true if any item in the collection is deeply equal to C<$data>.

=head2 tap(\&callback)

Returns a copy of the Iterator and executing callback on each item. This method works
like the Unix L<tee> command. Use this command to peek into an iterable while it is
processing results. E.g. you are writing code to process an iterable and wrote
something like:

   $it->each(sub {
	  # Very complicated routine
	  ....
   });

Now you would like to benchmark this piece of code (how fast are we processing).
This can be done by tapping into the iterator and calling a 'benchmark' subroutine
in your program that for instance counts the number of items divided by the
execution time.

   $it->tap(\&benchmark)->each(sub {
	  # Very complicated routine
	  ....
   });

   sub benchmark {
       my $item = shift;
       $start ||= time;
       $count++;

       printf "%d recs/sec\n" , $count/(time - $start + 1) if $count % 100 == 0;
   }

=head2 detect(\&callback)

Returns the first item for which callback returns a true value.

=head2 detect(qr/..../)

If the iterator contains STRING values, then return the first item which matches the
regex.

=head2 detect($key => $val)

If the iterator contains HASH values, then return the first item where the value of
$key is equal to val.

=head2 detect($key => qr/..../)

If the iterator contains HASH values, then return the first item where the value of
$key matches the regex.

=head2 detect($key => [$val, ...])

If the iterator contains HASH values, then return the first item where the value of
$key is equal to any of the vals given.

=head2 select(\&callback)

Returns an Iterator for each item for which callback returns a true value.

=head2 select(qr/..../)

If the iterator contains STRING values, then return each item which matches the regex.

=head2 select($key => $val)

If the iterator contains HASH values, then return each item where the value of
$key is equal to val.

=head2 select($key => qr/..../)

If the iterator contains HASH values, then return each item where the value of $key
matches the regex.

=head2 select($key => [$val, ...])

If the iterator contains HASH values, then return each item where the value of
$key is equal to any of the vals given.

=head2 reject(\&callback)

Returns an Iterator for each item for which callback returns a false value.

=head2 reject(qr/..../)

If the iterator contains STRING values, then reject every item except those
matching the regex.

=head2 reject($key => qr/..../)

If the iterator contains HASH values, then reject every item for where the value of $key
DOESN'T match the regex.

=head2 reject($key => $val)

If the iterator contains HASH values, then return each item where the value of
$key is NOT equal to val.

=head2 reject($key => [$val, ...])

If the iterator contains HASH values, then return each item where the value of
$key is NOT equal to any of the vals given.

=head3 BOOLEAN FUNCTIONS

=head2 any(\&callback)

Returns true if at least one item generates a true value when executing callback.

=head2 many(\&callback)

Alias for C<many>.

=head2 many(\&callback)

Returns true if at least two items generate a true value when executing callback.

=head2 all(\&callback)

Returns true if all the items generate a true value when executing callback.

=head3 MAP & REDUCE

=head2 map(\&callback)

Returns a new Iterator containing for each item the result of the callback.

=head2 reduce([START],\&callback)

Alias for C<reduce>.

=head2 reduce([START],\&callback)

For each item in the Iterator execute &callback($prev,$item) where $prev is the
option START value or the result of the previous call to callback. Returns the
final result of the callback function.

=head2 invoke(NAME)

This is a shortcut for $it->map(sub { $_[0]->NAME }).

=head2 max()

=head2 min()

=head1 SEE ALSO

L<Catmandu::Iterator>.

=cut

