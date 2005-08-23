package Maypole::FormBuilder::View;
use strict;
use warnings;

use Maypole::FormBuilder;
#use Class::Inspector;

our $VERSION = $Maypole::FormBuilder::VERSION;

# Maypole::Plugin::FormBuilder::init() does some funky messing about, which results in 
# this view class inheriting from Maypole::View::Base

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
    
=begin maybe
    
    if ( my $class = $r->model_class )
    {
        my $classmeta = $r->template_args->{classmetadata} ||= {};
        
        $classmeta->{name}              ||= $class;
        $classmeta->{model_class}       ||= $class;
        
        $classmeta->{table}             ||= $class->table;
        
        # MP::FB::Model defines lots of these methods, and developers are encouraged 
        # to define their own, so need to search for them at run time
        #$classmeta->{columns}           ||= [ $class->display_columns ];
        #$classmeta->{list_columns}      ||= [ $class->list_columns ];
        my @methods = grep { /^\w+_(?:columns|fields)$/ } Class::Inspector->methods( $class, 'public' );
        $classmeta->{ $_ } ||= [ $class->$_ ] for @methods;
        
        $classmeta->{colnames}          ||= { $class->column_names };
        $classmeta->{related_accessors} ||= [ $class->related($r) ];
        $classmeta->{moniker}           ||= $class->moniker;
        #$classmeta->{plural}            ||= $class->plural_moniker;
        #$classmeta->{cgi}               ||= { $class->to_cgi };
    }    
    
=end maybe

=cut
    
    # Overrides
    %args = ( %args, %{ $r->template_args || {} } );
    %args;
}

1;