package Catmandu::Fix::remove_field;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Fix::Base';

has path => (is => 'ro', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, $path) = @_;
    $orig->($class, path => $path);
};

sub emit {
    my ($self, $fixer) = @_;
    my $path = $fixer->split_path($self->path);
    my $key = pop @$path;

    $fixer->emit_walk_path($fixer->var, $path, sub {
        my $var = shift;
        $fixer->emit_delete_key($var, $key);
    });
}

=head1 NAME

Catmandu::Fix::remove_field - remove a field form the data

=head1 SYNOPSIS

   # Remove the foo.bar field
   remove_field('foo.bar');

=head1 SEE ALSO

L<Catmandu::Fix>

=cut

1;
