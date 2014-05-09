package Catmandu::Cmd::stores;
use Catmandu::Sane;
use parent 'Catmandu::Cmd';
use Catmandu::Importer::Stores;

sub command_opt_spec {
    (
        ["local|l!","list local packages",{ default => 1 }],
        ["verbose|v","include package information"]
    );
}
sub print_simple {
    my $record = $_[0];

    my @p = map { 
        "$_: ".$record->{$_}; 
    } grep { 
        defined($record->{$_}); 
    } qw(name file version);
   
    say join(', ',@p);
}

sub command {
    my ($self, $opts, $args) = @_;

    my $verbose = $opts->verbose;

    Catmandu::Importer::Stores->new(

        local => $opts->local

    )->each(sub{

        my $record = $_[0];
        
        unless($verbose){
            say $record->{name}
        }else{      
            print_simple($record);
        }
    });

}

1;

=head1 NAME

    Catmandu::Cmd::stores  -  list available Catmandu stores

=cut