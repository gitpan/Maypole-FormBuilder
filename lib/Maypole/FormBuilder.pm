package Maypole::FormBuilder;

use warnings;
use strict;

our $VERSION = 0.212;

=head1 NAME

Maypole::FormBuilder - CGI::FormBuilder support in Maypole

=head1 SYNOPSIS

    use Maypole::Application qw( FormBuilder QuickTable );
    
    BeerFB->config->model( 'Maypole::FormBuilder::Model' );

=head1 DESCRIPTION

L<Maypole|Maypole> provides a great framework for simplifying the interaction between 
a UI and a database. But it provides very little support for simplifying the interface 
itself. Programmers are left to construct each form, widget by widget, using modules that 
don't support important form use cases, such as what to do when a form submits nothing 
for an empty field. 

L<CGI::FormBuilder|CGI::FormBuilder> already supports this and many, many other forms 
use cases. And it provides validation methods, multiform support, and automatically 
generated Javascript validation code. And plenty more. 

This distribution uses L<Class::DBI::FormBuilder|Class::DBI::FormBuilder> to generate the 
metadata required to automatically build FormBuilder forms from CDBI classes and objects. 

The distribution includes:

=over 4

=item Maypole::FormBuilder

Introductory documentation only.

=item Maypole::Plugin::FormBuilder

C<as_form>, C<search_form> and C<as_forms> methods for the Maypole request 
object.

L<Maypole::Plugin::FormBuilder|Maypole::Plugin::FormBuilder>.

=item Maypole::FormBuilder::Model

A model class based on L<Class::DBI|Class::DBI>. Note that this model does B<not> 
inherit from L<Maypole::Model::CDBI|Maypole::Model::CDBI>. 

L<Maypole::FormBuilder::Model|Maypole::FormBuilder::Model>.

=item Maypole::FormBuilder::Model::Base

Model methods that do not depend on the CDBI backend. Models based on a different 
persistence layer may wish to inherit from this class. 

L<Maypole::FormBuilder::Model::Base|Maypole::FormBuilder::Model::Base>.

=item templates

A new set of templates for the Beer database. These are considerably simpler than the 
BeerDB templates. 

These templates are for Mason, but it should be a simple task to port them to other templating 
systems. 

Note that the templates also need L<Maypole::Plugin::QuickTable|Maypole::Plugin::QuickTable>.
    
=back

=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

Edit and update actions from the editable list template are broken. 

After creating or editing an object, if the return is to a list template, need to ensure the 
appropriate page is set. Or just go back to the original workflow and 
display the C<view> template instead. 

The development version of L<Class::DBI::Plugin::Pager|Class::DBI::Plugin::Pager> (which is 
the version I have installed) has a bug, so I haven't been able to test using it via the 
C<<BeerFB->config->pager_class>> setting.

Please report any bugs or feature requests to
C<bug-maypole-formbuilder@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Maypole-FormBuilder>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 TODO

Most links from the C<editlist> template return the user to the C<list> template, 
rather than staying in the C<editlist> view.

=head1 COPYRIGHT & LICENSE

Copyright 2005 David Baird, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Maypole::FormBuilder
