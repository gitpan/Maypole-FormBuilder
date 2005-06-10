package Maypole::FormBuilder::View;
use strict;
use warnings;

use Maypole::FormBuilder;
our $VERSION = $Maypole::FormBuilder::VERSION;

=over

=item vars

Overrides the standard Maypole::View::Base vars method, removing the C<classmetadata> entries.

=cut

sub vars 
{
    my ( $self, $r ) = @_;
    
    my $base  = $r->config->uri_base;
    $base =~ s/\/+$//;
    
    my %args = (
        request => $r,
        objects => $r->objects,
        base    => $base,
        config  => $r->config
    );
    
    # Overrides
    %args = ( %args, %{ $r->template_args || {} } );
    %args;
}

1;