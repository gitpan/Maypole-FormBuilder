package Maypole::FormBuilder::Model::Base;

use warnings;
use strict;

use base 'Maypole::Model::Base';

use Maypole::FormBuilder;
our $VERSION = $Maypole::FormBuilder::VERSION;

=head1 NAME

Maypole::FormBuilder::Model::Base

=head1 METHODS

=over 4

=item setup_form_mode

Returns a form spec for the selected form mode. The mode defaults to C<< $r->action >>. 
You can set a different mode in the args hash to the C<as_form> call. Mostly, this method is 
responsible for setting the C<action> parameter of the form. 

Override this in model classes to configure custom modes, and call 

    $proto->SUPER::setup_form_mode( $r, $args )
    
in the custom method if it doesn't know the mode.

Modes supported here are:

    list
    addnew
    search
    do_search
    
=cut

sub setup_form_mode
{
    my ( $proto, $r, $args ) = @_;
    
    # the mode is set in _get_form_args
    my $mode = delete( $args->{mode} ) || die "no mode for $proto";
    
    # -------------------------
    if ( $mode eq 'list' )
    {
        $args->{action} = $r->make_path( table      => $proto->table, 
                                         action     => 'list',
                                         );
    }
    
    # -------------------------
    elsif ( $mode eq 'addnew' )
    {
        $args->{action} = $r->make_path( table  => $proto->table, 
                                         action => 'addnew',
                                         );
    }
    
    # -------------------------
    # Usually, a search form is specified by setting the mode in a template (e.g. the 
    # list template). So it's fine to manually set the mode to 'search'. But if you want 
    # to have a separate search page, don't put it 
    # at $base/$table/search, because that'll execute the CDBI search method. Put 
    # it at $base/$table/do_search, or better yet, create your own modes and templates 
    # for $base/$table/advanced_search, $base/$table/simple_search etc.
    elsif ( $mode =~ /^(?:do_)?search$/ )
    {
        $args->{action} = $r->make_path( table  => $proto->table, # $r->table,
                                         action => 'do_search',
                                         );
    }
    
    # -------------------------
    else
    {
        die "No form specification found for mode '$mode' on item '$proto'";
    }
    
    return $args;
}

=back 

=head2 Exported Methods

=over 4

=item view

Just sets the C<view> template.

=cut

sub view : Exported
{
    my ( $self, $r ) = @_;

    $r->template( 'view' );
}

=item edit

Sets the C<edit> template. 

Also sets the C<action> to C<edit>. This is necessary 
to support forwarding to the C<edit> template from the C<edit> button on the C<editlist> 
template.

=cut

sub edit : Exported
{
    my ( $self, $r ) = @_;
    
    $r->action( 'edit' );
    
    $r->template( 'edit' );
}

=back 

=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-maypole-formbuilder@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Maypole-FormBuilder>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2005 David Baird, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;