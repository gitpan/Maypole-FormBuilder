package Maypole::FormBuilder::Model;
use warnings;
use strict;

use base qw( Maypole::FormBuilder::Model::Base 
             Class::DBI 
             );

use Class::DBI::Loader;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;

use Class::DBI::FormBuilder;

use Maypole::FormBuilder;
our $VERSION = $Maypole::FormBuilder::VERSION;

#use Class::DBI::Pager; - now loaded in MP::FB::setup()

#use Data::Dumper;

=head1 NAME

Maypole::FormBuilder::Model

=head1 SYNOPSIS

    BeerFB->config->model( 'Maypole::FormBuilder::Model' );

=head1 Major surgery

This class does not inherit from L<Maypole::Model::CDBI|Maypole::Model::CDBI>, for several 
reasons. We don't need to load Class::DBI::Untaint, Class::DBI::AsForm or Class::DBI::FromCGI. 
I wanted to implement a config option to choose which pager to use (see C<do_pager>). And I 
wanted to rename methods that share a name with methods in Class::DBI (C<delete> and C<search> are 
now C<do_delete> and C<do_search>).

Maypole is pretty stable these days and it should be easy enough to keep up with any bug fixes. 

=head1 METHODS

=over 4
    
=item setup_form_mode

See C<Maypole::FormBuilder::Model::Base::setup_form_mode()>.

Modes supported here are:

    ${action}_button    where $action is any public action on the class
    editlist
    edit
    do_edit
    
=cut

sub setup_form_mode
{
    my ( $proto, $r, $args ) = @_;
    
    # the mode is set in _get_form_args
    my $mode = $args->{mode} || die "no mode for $proto";
    
    my $pk = $proto->primary_column;
        
    my %additional = ref( $proto ) ? ( additional => $proto->$pk ) : ();
    
    # -------------------------
    if ( $mode =~ /^(\w+)_button$/ )
    {
        my $button_name = $1;
        
        my %despatch = ( delete => 'do_delete' );
        
        my $maypole_action = $despatch{ $button_name } || $button_name;
        
        $args->{action} = $r->make_path( table      => $proto->table, 
                                           action     => $maypole_action,
                                           %additional, 
                                           );
        $args->{fields} = [];
        $args->{submit} = $button_name;
        $args->{table}  = 0; # don't place the form inside a table
        
        if ( $button_name eq 'delete' )
        {
            $args->{jsfunc} = <<EOJS
if (form._submit.value == "delete") {
    if (confirm("Really DELETE this entry?")) return true;
    return false;
}
EOJS
        }
    }    
    
    # -------------------------
    # This is for generating a single form (i.e. row) within the editable list table. 
    # Note that although it's a 'list' action, it is associated with a single object 
    # (specified in %additional). The list() public method does whatever needs to be 
    # done with that object, and then returns via _list(), which regenerates the list 
    # page.
    elsif ( $mode eq 'editlist' )
    {
        $args->{action} = $r->make_path( table      => $proto->table, # $r->table
                                           action     => 'editlist',
                                           %additional,
                                           );
    }
    
    # -------------------------
    elsif ( $mode =~ /^(?:do_)?edit$/ )
    {
        $args->{action} = $r->make_path( table      => $proto->table,
                                           action     => 'do_edit',
                                           %additional, 
                                           );
    }
    
    # -------------------------
    else
    {
        return $proto->SUPER::setup_form_mode( $r, $args )
    }
    
    delete $args->{mode};
    
    return $args;
}


# --------------------------------------------------------- utility -----
=item display_columns

Returns a list of columns, minus primary key columns, which probably don't 
need to be displayed. 

Note that L<Class::DBI::FormBuilder|Class::DBI::FormBuilder> will add back in 
B<hidden> fields for the primary key(s), to support lookups done in several of 
its C<*_from_form> methods. 

=cut

sub display_columns 
{ 
    my ( $proto ) = @_;
    
    my %pk = map { $_ => 1 } $proto->primary_columns;
    
    return grep { ! $pk{ $_ } } $proto->columns( 'All' );
}

# ------------------------------------------------------------ exported methods -----

=back

=head2 Exported methods

As a convenience, all these methods now set the appropriate template, so it shouldn't 
be necessary to set the template and then call the method. This is particularly useful in 
despatching methods, such as C<editlist>.

Some exported methods are defined in L<Maypole::FormBuilder::Model::Base|Maypole::FormBuilder::Model::Base>, 
if they have no dependency on CDBI.

=head3 Gotchas

Sometimes you need to set the form mode in these methods, sometimes not. I B<think> that if 
the mode matches the action, you don't need to set it. 
So to get searching working, the C<do_search> mode needs to be set. Similarly for C<do_edit>, 
except here the C<edit> mode needs to be set. Elsewhere the mode is automatically set to the 
Maypole action. If you insert a line in CGI::FormBuilder::submitted() to 
C<warn> the value of C<$smtag>, that needs to match the name of the submit button in 
C<< $request->params >> (i.e. C<< $request->params->{$smtag} >> needs to be true). 

=over 4

=item addnew

The way L<CGI::FormBuilder|CGI::FormBuilder> handles different button clicks (i.e. it handles them), 
means we need a separate method for creating new objects (in standard Maypole, addnew 
posts to C<do_edit>). But L<Class::DBI::FormBuilder|Class::DBI::FormBuilder> keeps things 
simple.

=cut

sub addnew : Exported
{
    my ( $self, $r ) = @_;
    
    my $form = $r->as_form;
    
    return $self->list( $r ) unless $form->submitted && $form->validate;
    
    $r->model_class->create_from_form( $form ) || die "Unexpected create error";
    
    $self->list( $r );
}

=item do_edit

Implements update operations on submitted forms.

=cut

sub do_edit : Exported
{
    my ( $self, $r ) = @_;
    
    my $caller = (caller(1))[3];
    
    # the mode of the generated form must match the mode of the submitted from, 
    # so that the submit button can be detected accurately
    my $form_mode = $caller =~ 'editlist' ? 'editlist' : 'edit';
    
    my $form = $r->as_form( mode => $form_mode ); 
    
    # default template for this action
    $r->template( 'edit' );
    
    # Do nothing if no form submitted, or failed validation. If the latter, 
    # errors will be displayed by magic in the form. Note that if coming from 
    # editlist, any form errors will divert us to the edit template (showing errors), 
    # rather than returning to the editlist template. Which seems like the right behaviour.
    return unless $form->submitted && $form->validate;
    
    # This assumes the primary keys in the form (hidden fields) identify 
    # the same object as in the URL, which will already be in $r->objects->[0].
    # They should be, because the form was generated either from a specific object 
    # (so C::DBI::FB inserted the hidden fields), or was generated from the class, 
    # and therefore has no pk data and will result in a create.
    
    # If for some reason, the model_class is different from the class of $r->objects->[0], 
    # then use ref( $r->objects->[0] ) instead. But that shouldn't happen...
    
    my $model = $r->model_class;
    
    # dunno why I was getting this error, probably don't need to check this now
    Carp::croak( "model ($model) is not a class name!" ) if ref( $model );

    my $obj = $model->update_from_form( $form ) || 
        die "Unexpected update error"; # Don't you just hate this kind of message?
    
    $r->objects( [ $obj ] );
    
    my $return_method = $caller =~ /editlist/ ? 'list' : 'view';
    
    $self->$return_method( $r );
}

=item search

Runs a C<search_where> search. 

Does not implement search ordering yet, and there are various other
modifications that could make this better, such as allowing C<LIKE> comparisons (% and _ wildcards) 
etc. 

=cut

sub do_search : Exported 
{
    my ( $self, $r ) = @_;

    # not sure why this is necessary, the search form submits directly to 
    # do_search anyway    
    my $form = $r->search_form( mode => 'do_search' );
    
    $r->{template_args}{search} = 1;
    
    return $self->list( $r ) unless $form->submitted && $form->validate; 
    
    $r->template( 'list' );
    
    $self = $self->do_pager( $r );
    
    $r->objects( [ $self->search_where_from_form( $form ) ] );
}

=item editlist

Detects which submit button was clicked, and despatches to the appropriate method. 

=cut

sub editlist : Exported
{
    my ( $self, $r ) = @_;
    
    my $form = $r->as_form;
    
    my $button = $form->submitted if $form->validate;
    
    return $self->do_edit  ( $r )   if $button eq 'update';
    return $self->edit     ( $r )   if $button eq 'edit';
    return $self->do_delete( $r )   if $button eq 'delete';
    return $self->view     ( $r )   if $button eq 'view';
    
    return $self->list     ( $r );
}

=item list 

Does not implement ordering yet.

=cut

sub list : Exported
{
    my ( $self, $r ) = @_;

    $r->template( 'list' );
    
    #my $order = $self->order($r);
    
    $self = $self->do_pager($r);
    
    #if ($order) 
    #{
    #    $r->objects( [ $self->retrieve_all_sorted_by($order) ] );
    #}
    #else 
    #{
        $r->objects( [ $self->retrieve_all ] );
    #}    
}

=item do_delete

Deletes a single object. 

=cut

sub do_delete : Exported 
{
    my ( $self, $r ) = @_;
    
    my $goner = @{ $r->objects || [] }[0];
    
    $goner && $goner->delete;
    
    $self->list( $r );
}

=item switchlistmode

If sessions are enabled, this switches the default list mode between C<editlist> and C<list>.

=cut

sub switchlistmode : Exported
{
    my ( $self, $r ) = @_;
    
    my %switch_from = ( list => 'editlist',
                        editlist => 'list',
                        );
                   
    my $old_mode = $r->listviewmode;
    
    $r->listviewmode( $switch_from{ $old_mode } );
    
    # set this so forms built on the list page don't look for a switchlistmode 
    # form mode
    $r->action( 'list' );
    
    return $self->list( $r );
}

# -------------------------------------------------------- other Maypole::Model::CDBI methods -----

=back 

=head2 Maypole::Model::CDBI methods

These methods are copied verbatim from L<Maypole::Model::CDBI|Maypole::Model::CDBI>. 
See that module for documentation. 

=over 4

=item related

=item related_class

=item stringify_column

=item adopt

=item do_pager

The default pager is L<Class::DBI::Pager|Class::DBI::Pager>. Use a different pager 
by setting the C<pager_class> config item:

    BeerFB->config->pager_class( 'Class::DBI::Plugin::Pager' );

=item order

This method is not used in the C<Maypole::Plugin::FormBuilder> templates at the moment. 
Probably, ordering will be implemented directly in L<Class::DBI::FormBuilder|Class::DBI::FormBuilder> 
and this method can disappear. 

=item setup_database

=item class_of

=item fetch_objects

=back

=cut

sub related {
    my ( $self, $r ) = @_;
    return keys %{ $self->meta_info('has_many') || {} };
}



sub related_class {
    my ( $self, $r, $accessor ) = @_;

    my $related = $self->meta_info( has_many => $accessor ) ||
                  $self->meta_info( has_a    => $accessor ) ||
                  return;

    my $mapping = $related->{args}->{mapping};
    if ( @$mapping ) {
        return $related->{foreign_class}->meta_info('has_a')->{ $$mapping[0] }
          ->{foreign_class};
    }
    else {
        return $related->{foreign_class};
    }
}

sub stringify_column {
    my $class = shift;
    return (
        $class->columns("Stringify"),
        ( grep { /(name|title)/i } $class->columns ),
        ( grep { !/id$/i } $class->primary_columns ),
    )[0];
}

sub adopt {
    my ( $self, $child ) = @_;
    $child->autoupdate(1);
    if ( my $col = $child->stringify_column ) {
        $child->columns( Stringify => $col );
    }
}

sub do_pager {
    my ( $self, $r ) = @_;
    if ( my $rows = $r->config->rows_per_page ) {
        return $r->{template_args}{pager} =
          $self->pager( $rows, $r->query->{page} );
    }
    else { return $self }
}

sub order {
    my ( $self, $r ) = @_;
    my $order;
    my %ok_columns = map { $_ => 1 } $self->columns;
    if ( $order = $r->query->{order} and $ok_columns{$order} ) {
        $order .= ( $r->query->{o2} eq "desc" && " DESC" );
    }
    $order;
}

sub setup_database {
    my ( $class, $config, $namespace, $dsn, $u, $p, $opts ) = @_;
    $dsn  ||= $config->dsn;
    $u    ||= $config->user;
    $p    ||= $config->pass;
    $opts ||= $config->opts;
    $config->dsn($dsn);
    warn "No DSN set in config" unless $dsn;
    $config->loader || $config->loader(
        Class::DBI::Loader->new(
            namespace => $namespace,
            dsn       => $dsn,
            user      => $u,
            password  => $p,
            options   => $opts,
        )
    );
    $config->{classes} = [ $config->{loader}->classes ];
    $config->{tables}  = [ $config->{loader}->tables ];
    warn( 'Loaded tables: ' . join ',', @{ $config->{tables} } )
      if $namespace->debug;
}

sub class_of {
    my ( $self, $r, $table ) = @_;
    return $r->config->loader->_table2class($table);
}

sub fetch_objects {
    my ($class, $r)=@_;
    my @pcs = $class->primary_columns;
    if ( $#pcs ) {
    my %pks;
        @pks{@pcs}=(@{$r->{args}});
        return $class->retrieve( %pks );
    }
    return $class->retrieve( $r->{args}->[0] );
}
 
=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

Searching isn't working yet, probably more to do with CDBI::FormBuilder.

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