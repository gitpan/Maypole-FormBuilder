package Maypole::Plugin::FormBuilder;

use warnings;
use strict;

use NEXT;
use UNIVERSAL::require;

use Maypole::FormBuilder::View;
use Maypole::Config;
use Maypole::FormBuilder;

Maypole::Config->mk_accessors( qw( form_builder_defaults pager_class ) );

our $VERSION = $Maypole::FormBuilder::VERSION;

=head1 NAME

Maypole::Plugin::FormBuilder - CGI::FormBuilder for Maypole

=head1 SYNOPSIS

    package BeerFB;
    use warnings;
    use strict;
    
    use Class::DBI::Loader::Relationship;
    use Apache::Session::File();
    
    use Maypole::Application qw( FormBuilder QuickTable Session );
    
    BeerFB->config->model( 'Maypole::FormBuilder::Model' );
    
    BeerFB->config->session( { args => { Directory     => "/tmp/sessions/beerfb",
                                         LockDirectory => "/tmp/sessions/beerfb",
                                         },
                               } );
    
    # note: the latest development version is broken
    #BeerFB->config->pager_class( 'Class::DBI::Plugin::Pager' );
    
    # global FormBuilder defaults
    BeerFB->config->form_builder_defaults( method => 'post' );
    
    # standard config
    BeerFB->config->{template_root}  = '/home/beerfb/www/www/htdocs';
    BeerFB->config->{uri_base}       = '/';
    BeerFB->config->{rows_per_page}  = 10;
    BeerFB->config->{display_tables} = [ qw( beer brewery pub style ) ];
    BeerFB->config->{application_name} = 'The BeerFB Database';

    BeerFB->setup( 'dbi:mysql:BeerDB', 'username', 'password' );
    
    BeerFB->config->loader->relationship( $_ ) for (
        'a brewery produces beers',
        'a style defines beers',
        'a pub has beers on handpumps',
        );
    
    # ----- set up validation and other form defaults -----
    
    # has_a fields (style, brewery) are automatically required in CDBI::FormBuilder
    BeerFB::Beer->columns( Required => qw( name ) ); 
    BeerFB::Beer->form_builder_defaults( { validate => { abv     => 'NUM',
                                                        style   => 'INT',
                                                        brewery => 'INT',
                                                        price   => 'NUM',
                                                        url     => 'VALUE',
                                                        notes   => 'VALUE',
                                                        name    => 'VALUE',
                                                        score   => [ qw( 1 2 3 4 5 ) ],
                                                        },
                                        options => { score => [ qw( 1 2 3 4 5 ) ],
                                                        },
                                        } );
        
    BeerFB::Brewery->columns( Required => qw( name ) );
    BeerFB::Brewery->form_builder_defaults( { validate => { name  => 'VALUE',
                                                            notes => 'VALUE',
                                                            url   => 'VALUE',
                                                            },
                                            } );
                                            
    # or put the required columns in the CGI::FormBuilder default spec:
    BeerFB::Pub->form_builder_defaults( { validate => { name  => 'VALUE',
                                                        notes => 'VALUE',
                                                        url   => 'VALUE',
                                                        },
                                        required => [ qw( name ) ],
                                        } );
                                            
    BeerFB::Style->form_builder_defaults( { validate => { name  => 'VALUE',
                                                          notes => 'VALUE',
                                                          },
                                            required => [ qw( name ) ],
                                            } );    
    
    1;
    
    
    # -------------------------------------------------------------------------
    # --- in a Mason template (adapt syntax for your preferred template system)
    
    <% $request->as_form->render %>
    
=head1 DESCRIPTION

Generate L<CGI::FormBuilder|CGI::FormBuilder> forms from Maypole objects, using L<Class::DBI::FormBuilder|Class::DBI::FormBuilder>. 

Includes an alternative Maypole model, which should be set up in your config:

    BeerFB->config->model( 'Maypole::FormBuilder::Model' );

B<Note> that a new C<vars> method is installed, which removes the 
C<classmetadata> functionality. It just seemed like an extra level of API to learn, 
and we don't need the L<Class::DBI::AsForm|Class::DBI::AsForm> stuff.

=head2 Sessions

The demo application (shown in the synopsis) uses sessions to keep track of the user's 
preferred list view mode (editlist or plain list). The demo should work without sessions, 
but it will not show the editable list view.  

=head1 METHODS

=over 4

=item setup

=cut

sub setup
{
    my $class = shift;
    
    # ensure Maypole::setup() is called, which will load the model class
    $class->NEXT::DISTINCT::setup( @_ );

    $class->config->{form_builder_defaults} ||= {};
    $class->config->{pager_class}           ||= 'Class::DBI::Pager';
    
    my $model = $class->config->model ||
        die "Please configure a model in $class before calling setup()";
        
    my $pager = $class->config->{pager_class};
    
    eval "package $model; use $pager";
    die $@ if $@;
}

=item init

=cut

sub init
{
    my ( $class ) = @_;
    
    my $config = $class->config;

    $class->NEXT::DISTINCT::init;
    
    my $old_view = $class->config->view ||
        die "Please configure a view in $class before calling init()";
        
    my $virtual_view = "$class\::__::View";
    
    eval <<VIEW;
package $virtual_view; 
use base qw( Maypole::FormBuilder::View $old_view );
VIEW
          
    die $@ if $@;
    
    $config->view( $virtual_view );
    
    $class->view_object( $class->config->view->new );
}

=item as_form

This returns a L<CGI::FormBuilder|CGI::FormBuilder> object. Accepts any parameters that 
C<< CGI::FormBuilder->new() >> accepts. 

Defaults are as in L<CGI::FormBuilder|CGI::FormBuilder>, you can alter them using 
the C<form_builder_default> Maypole config slot.

There are a few additional Maypole-specific options:
    
=over 4
    
=item mode

The form generated depends on the C<mode>. Defaults to the current action.

Pass this argument to generate a different form from that specified by the current 
value of C<< $r->action >>. For instance, to generate a search form to include on a 
list template, say 

    print $r->as_form( mode => 'do_search' )->render;
    
You can add more modes by defining C<setup_form_mode> methods in your model classes. See 
L<Maypole::FormBuilder::Model|Maypole::FormBuilder::Model> and 
L<Maypole::FormBuilder::Model::Base|Maypole::FormBuilder::Model::Base>.

=item entity

Normally, C<as_form> builds a form based on the first object 
in C<< $r->objects >>, or based on the current model (C<< $r->model_class >>) if there are no 
objects. To use a different object or model, pass it in the C<entity> argument:

    my $form = $r->as_form( entity => $class_or_object );
    
=back

=cut

sub as_form
{
    my ( $r, %args ) = @_;
    
    my $entity = delete( $args{entity} ) || ( @{ $r->objects || [] } )[0] || $r->model_class;
    
    my $as_form = delete( $args{_as_form_} ) || 'as_form';
    
    die "Entity $entity is not a Maypole thang" unless $entity->isa( 'Maypole::Model::Base' );
    
    %args = $r->_get_form_args( $entity, %args );
    
    my $get_request = $r->can( 'ar' ) || $r->can( 'cgi' ) || die "no method for getting request";    
    
    $args{params} ||= $r->$get_request;

    # now modify for the Maypole action/mode - setup_form_mode() is in 
    # Maypole::Plugin::FormBuilder::Model::Base, but can be overridden in specific 
    # model classes
    my $spec = $entity->setup_form_mode( $r, \%args );
    
    return $entity->$as_form( %$spec );
}

=item as_form_with_related


=cut

sub as_form_with_related
{
    my ( $r, %args ) = @_;

    return $r->as_form( _as_form_ => 'as_form_with_related', %args );
}


=item search_form

Returns a search form, via C<Class::DBI::FormBuilder::search_form()>. The C<mode> 
defaults to C<do_search>. 

=cut

sub search_form
{
    my ( $r, %args ) = @_;
    
    my $class = delete( $args{entity} ) || $r->model_class;
    
    die "search_form() must be called on a class, not an object" if ref( $class );
    
    # this must be set before calling _get_form_args()
    $args{mode} ||= 'search'; # or do_search - both set the form action to do_search in setup_form_mode()
    
    $args{required} ||= [];

    %args = $r->_get_form_args( $class, %args );
    
    my $get_request = $r->can( 'ar' ) || $r->can( 'cgi' ) || die "no method for getting request";    
    
    $args{params} ||= $r->$get_request;    
    
    my $spec = $class->setup_form_mode( $r, \%args );
    
    # remember search terms if the current request is processing a search form
    $spec->{sticky} = $r->action =~ /^(?:do_)?search$/;
    
    return $class->search_form( %$spec );
}
    
sub _get_form_args
{
    my ( $r, $proto, %args ) = @_;

    # CDBI::FB will later merge in %{ $proto->form_builder_defaults }, 
    %args = ( %{ $r->config->form_builder_defaults }, 
              %args,
              );
              
    $args{mode} ||= $r->action;
    
    $args{fields} ||= [ map {''.$_} $proto->display_columns ]; 

    # Give every form a (hopefully) unique name.
    my @name;
    
    if ( my $cl = ref( $proto ) )
    {
        push @name, $cl, $args{mode}, map { $proto->get( $_ ) } $proto->primary_columns;
    }
    else
    {
        push @name, $proto, $args{mode};
    }
    
    # Need to use a separator that is legal in javascript function names (not .) and 
    # CSS identifiers (not _ ?). Need to use a separator in case of multiple primary columns.
    # CGI::FB will still add an underscore to some identifiers though. 
    $args{name} ||= join( '_', @name ); 
                          
    $args{name} =~ s/[^\w]+/_/g;

    return %args;
}

=item as_forms( %args )

    %args = ( objects       => $object|$arrayref_of_objects,    defaults to $r->objects
              no_textareas  => true|false value,                default false
              %other_form_args,
              );

Generates multiple forms and returns them as a list.

You will probably want to set C<no_textareas> to true (converts them to text inputs), and perhaps 
reduce C<selectnum> ( see the C<list> template in this distribution).

=cut

sub as_forms
{
    my ( $r, %args ) = @_;
    
    my $objects       = delete $args{objects} || $r->objects;
    my $no_textareas  = delete $args{no_textareas};
    
    my @objects = ref( $objects ) eq 'ARRAY' ? @$objects : ( $objects );
    
    my @forms;
    
    foreach my $object ( @objects )
    {
        my $form = $r->as_form( %args, entity => $object );
        
        push @forms, $form;
        
        next unless $no_textareas;
                                    
        foreach my $field ( $form->field )
        {
            # change textareas into text inputs
            $form->field( name => $field,
                          type => 'text',
                          ) if $field->type eq 'textarea';
        }   
    }
    
    return @forms;
}    

=item render_form_as_row( $form )

Returns a form marked up as a single row for a table. 

=cut
    
# chopped out of CGI::FormBuilder::render()
sub render_form_as_row
{
    my ( $r, $form ) = @_;
    
    my $font = $form->font;
    my $fcls = $font ? '</font>' : '';
    
    my $html;
    
    # JavaScript validate/head functions
    if ( my $sc = $form->script ) 
    {
        $html .= $sc . $form->noscript;
    }    
    
    $html .= "<tr>\n" . $form->start . "\n" . $form->statetags . "\n" . $form->keepextras;
    
    my $table = $form->table;

    # Render hidden fields first
    my @unhidden;
    
    foreach my $field ( $form->field ) 
    {
        push( @unhidden, $field ), next if $field->type ne 'hidden';
        
        $html .= $field->tag . "\n";   # no label/etc for hidden fields
    }

    foreach my $field ( @unhidden ) 
    {
        next if $field->static && $field->static > 1 && ! $field->tag_value;  # skip missing static vals
        
        if ( $table ) 
        {
            $html .= $form->td . $font . $field->tag;
            $html .= ' ' . $field->comment if $field->comment && ! $field->static;
            $html .= ' ' . $field->message if $field->invalid;
            $html .= $fcls . "</td>\n";
        }
        else
        {
            $html .= $field->label . ' ' . $field->tag . ' ';
            $html .= '<br />' if $form->linebreaks;
        }
    }
    
    # buttons
    my $buttons = $form->reset . $form->submit;
    
    if ( $buttons ) 
    {
        if ($table) 
        {
            my @buttons = split( '><', $form->reset . $form->submit );
            do { $_ .= '>' unless />$/; $_ = "<$_" unless /^</; } for @buttons;
            $html .= $form->td . $font . "${_}${fcls}</td>\n" for @buttons;
        }
        else
        {
            $html .= $buttons;
        }
    }
        
    # close off the form and row
    $html .= "</form>\n</tr>\n";
        
    return $html;
}


=item Maypole::Config::form_builder_defaults()

Defaults that apply to all forms. 

    # make all forms POST their data
    BeerFB->config->form_builder_defaults->{method} = 'post';

=item listviewmode

A convenience method to allow the default templates 
to work without a session. With no session configured, always returns C<list>. With a session, 
returns/sets the list view mode, which can be C<list> or C<editlist>.

=cut

sub listviewmode
{
    my ( $r, $new_mode ) = @_;
    
    return 'list' unless $r->can( 'session' );
    
    my $mode = $r->session->{listviewmode} || 'list';
    
    return $mode unless $new_mode;
    
    die "List view mode must be 'list' or 'editlist'" 
        unless $new_mode =~ /^(?:edit)?list$/;
        
    $r->session->{listviewmode} = $new_mode;
    
    return $mode;
}

=back

=head1 Configuring custom actions

Custom actions may require custom configuration of the form object (in addition to providing an Exported method in your model class to support the new action). Write a C<setup_form_mode> 
method in your model class. See 
L<Maypole::Plugin::FormBuilder::Model::Base|Maypole::Plugin::FormBuilder::Model::Base>.

=head1 SEE ALSO

L<Maypole::FormBuilder::Model|Maypole::FormBuilder::Model> and 
L<Maypole::FormBuilder::Model::Base|Maypole::FormBuilder::Model::Base>.

=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

The way the pager is loaded (in setup()) means that every Maypole app in the current 
interpreter that uses the same model, will be using the same pager. I've no immediate plans 
to fix this unless someone asks me.

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

1; # End of Maypole::Plugin::FormBuilder
