package Maypole::FormBuilder::Model;
use warnings;
use strict;

use base qw( Maypole::Model::Base 
             Class::DBI 
             );

use Class::DBI::Loader;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;
use Class::DBI::Plugin::Type;

use Class::DBI::FormBuilder; # 0.34;

use Maypole::FormBuilder;

our $VERSION = $Maypole::FormBuilder::VERSION;

#use Class::DBI::Pager; - now loaded in MP::Plugin::FB::setup()

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

This method is responsible for ensuring that the 'server' form and the 'client' form are 
equivalent - see I<Coordinating client and server forms>.

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
    ${action}_button    where $action is any public action on the class
    editlist
    edit
    do_edit
    editrelated
    addto
    
=cut

sub setup_form_mode
{
    my ( $proto, $r, $args ) = @_;
    
    # the mode is set in _get_form_args
    my $mode = $args->{mode} || die "no mode for $proto";
    
    my $pk = $proto->primary_column;
        
    my %additional = ref( $proto ) ? ( additional => $proto->$pk ) : ();
    
    # XXX this needs to be refactored into a dispatch table
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
    elsif ( $mode =~ /^(\w+)_button$/ )
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
                                         
        $args->{fields} = [ $proto->list_columns, $proto->list_fields ];
    }
    
    # -------------------------
    elsif ( $mode =~ /^(?:do_)?edit$/ )
    {
        $args->{action} = $r->make_path( table      => $proto->table,
                                         action     => 'do_edit',
                                         %additional, 
                                         );
                                           
        $args->{reset}  = 'reset';
        $args->{submit} = 'submit';
        $args->{fields} = [ $proto->display_columns ], # $proto->related ];
    }
    
    # -------------------------
    elsif ( $mode eq 'addto' )
    {
        $args->{action} = $r->make_path( table      => $proto->table,
                                         action     => 'addto',
                                         );
        
        # the template will already set this to +SET_VALUE(Some::Class) for the 
        # client, but we must ensure the field exists on the server form
        if ( my $p = $args->{process_fields}->{__target_class__} )
        {   # client form
            $p = [ $p, '+HIDDEN' ];
            $args->{process_fields}->{__target_class__} = $p;
        }
        else
        {   # server form
            $args->{process_fields}->{__target_class__} = '+ADD_FIELD'; 
        }
    }
    
    # -------------------------
    elsif ( $mode eq 'editrelated' )
    {
        $args->{action} = $r->make_path( table      => $proto->table,
                                         action     => 'editrelated',
                                         %additional, 
                                         );
    }
    
    # -------------------------
    else
    {
        die "No form specification found for mode '$mode' on item '$proto'";
    }
    
    delete $args->{mode};
    
    return $args;
}


# ---------------------------------------------------------------------------------- utility -----

=back

=head2 Column and field lists

=over

=item display_columns

Returns a list of columns, minus primary key columns, which probably don't 
need to be displayed. The templates use this as the default list of columns 
to display. 

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

=item list_columns

This method is not defined here, but in L<Maypole::Model::Base|Maypole::Model::Base>, and 
defaults to C<display_columns>. This is used to define the columns displayed in the C<list> 
template. 

=item related

Returns a list of accessors for C<has_many> related classes. These can appear as fields in a 
form, but are not columns in the database. 

=item list_fields

This method is new in L<Maypole::FormBuilder|Maypole::FormBuilder>. Defaults to C<related>. 

The C<list> template uses C<list_columns> plus C<list_fields> as the default list of fields to 
display, and C<setup_form_mode> sets C<list_columns> plus C<list_fields> in the C<fields> 
argument in C<editlist> mode, so that editable and navigable list views both present the same 
fields. 

=cut

sub list_fields
{
    my ( $proto ) = @_;
    
    $proto->related;
}

# ------------------------------------------------------------ exported methods -----

=back

=head2 Exported methods

Exported methods have the C<Exported> attribute set. These are the methods that URLs can trigger. 
See the main Maypole documentation for more information. 

As a convenience and a useful convention, all these methods now set the appropriate template, 
so it shouldn't be necessary to set the template and then call the method. This is particularly useful in 
despatching methods, such as C<editlist>.

Some exported methods are defined in L<Maypole::FormBuilder::Model::Base|Maypole::FormBuilder::Model::Base>, 
if they have no dependency on CDBI. But the likelihood of a FormBuilder distribution that doesn't depend 
on L<Class::DBI::FormBuilder|Class::DBI::FormBuilder> is pretty low.

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

=item addto

=cut

sub addto : Exported
{
    my ( $self, $r ) = @_;
    
    my $form = $r->as_form;
    
    return $self->list( $r ) if $r->model_class->create_from_form( $form );
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

=item do_search

Runs a C<search_where> search. 

Does not implement search ordering yet, and there are various other
modifications that could make this better, such as allowing C<LIKE> comparisons (% and _ wildcards) 
etc. 

=cut

sub do_search : Exported 
{
    my ( $self, $r ) = @_;

    my $form = $r->search_form;
    
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
    
    # something like "my_col DESC" or just "my_col" (for ASC)
    my $order = $self->order( $r );
    
    $self = $self->do_pager( $r );
    
    if ( $order ) 
    {
        $r->objects( [ $self->retrieve_all_sorted_by( $order ) ] );
    }
    else 
    {
        $r->objects( [ $self->retrieve_all ] );
    }    
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

=item view

Just sets the C<view> template.

=cut

sub view : Exported
{
    my ( $self, $r ) = @_;

    $r->template( 'view' );
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

=item editrelated

Basic support for the C<editrelated> template. This is currently under development 
in C<Class::DBI::FormBuilder::as_form_with_related()>.

=cut

sub editrelated : Exported
{
    my ( $self, $r ) = @_;

    my $form = $r->as_form_with_related( debug => 2 );
    
    warn "START";
    
    return $self->edit( $r ) unless $form->submitted && $form->validate;
    
    warn "GOT FORM";
    
    $r->objects( [ $self->update_from_form_with_related( $form ) ] );
    
    warn "DONE UPDATING: $self $r @{ $r->{objects} }";
    
    $self->view( $r );
}



# -------------------------------------------------------- other Maypole::Model::CDBI methods -----

=back 

=head2 Coordinating client and server forms

Every form is used in two circumstances, and the forms must be built with equivalent properties in 
each. In the first, a form object is constructed and used to generate an HTML form to be sent to the 
client. In the second, a form object is constructed and is used to receive data sent in a form 
submission from the client. These may be loosely termed the 'server' and 'client' forms (although they are 
both built on the server). 

The forms built in these two situations must have equivalent properties, such as the 
same field lists, the same option lists for multi-valued fields, etc. 

The point of co-ordination is the C<setup_form_mode> method. This supplies the set of characteristics 
that must be synchronised by both versions of the form. C<setup_form_mode> selects a set of form 
parameters based on the current C<action> of the Maypole request. 

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
            %$opts,
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

=head1 TODO

Refactor setup_form_mode() into a dispatch table.

I think splitting modes into search and do_search, and edit and do_edit, is 
probably unnecessary.

Pairs of methods like search and do_search, edit and do_edit are probably 
unnecessary, as FB makes it easy to distinguish between rendering a form 
and processing a form - see editrelated().

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