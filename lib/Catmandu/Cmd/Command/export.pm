package Catmandu::Cmd::Command::export;
# VERSION
use Moose;
use Catmandu::Util qw(load_class);

extends qw(Catmandu::Cmd::Command);

with qw(
    Catmandu::Cmd::Opts::Exporter
    Catmandu::Cmd::Opts::Store
    Catmandu::Cmd::Opts::Fix
);

has load => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'l',
    documentation => "The id of a single object to load and export.",
);

sub execute {
    my ($self, $opts, $args) = @_;

    $self->exporter =~ /::/ or $self->exporter("Catmandu::Exporter::" . $self->exporter);
    $self->store =~ /::/ or $self->store("Catmandu::Store::" . $self->store);

    if (my $arg = shift @$args) {
        $self->exporter_arg->{file} = $arg;
    }

    load_class($self->exporter);
    load_class($self->store);

    my $exporter = $self->exporter->new($self->exporter_arg);
    my $store = $self->store->new($self->store_arg);

    if ($self->load) {
        my $obj = $store->load_strict($self->load);
        if ($self->has_fix) {
            $obj = $self->fixer->fix($obj);
        }
        $exporter->dump($obj);
    } else {
        if ($self->has_fix) {
            $store = $self->fixer->fix($store);
        }
        $exporter->dump($store);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
no Catmandu::Util;
1;

=head1 NAME

Catmandu::Cmd::Command::export - export a store to a data file

