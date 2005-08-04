package Posy::Plugin::Categories;
use strict;

=head1 NAME

Posy::Plugin::Categories - Posy plugin to give category links.

=head1 VERSION

This describes version B<0.6501> of Posy::Plugin::Categories.

=cut

our $VERSION = '0.6501';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
		  Posy::Plugin::TextTemplate
		  ...
		  Posy::Plugin::Categories);

=head1 DESCRIPTION

This provides category-based (lists of) links:
a category tree which can be used as a site map, contains
a list of lists of all the categories; and
a breadcrumb list which provides a "breadcrumb trail" list.

These methods can be called from within templates if one is using
the TextTemplate plugin.

For example:

[==Posy->category_tree()==]

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the config directory.

=over

=item B<categories_hide>

Default value for categories not to show in the breadcrumb or
category tree.  The 'hide' value can also be set in the actual
call as well, which will override the config value.

=item B<categories_labels>

Optional hash which can only be set if one also has
L<Posy::Plugin::YamlConfig> or something similar.

By default, this uses prettified names of the category directories
to use as labels.  This hash provides replacement labels to use
if you prefer longer, more descriptive names.

For example:

    category_labels:
	b7: "Blake's 7"
	b5: "Babylon 5"

=back

=cut

=head1 Helper Methods

Methods which can be called from elsewhere.

=head2 category_tree

    $links = $self->category_tree(
	tree_head=>'<ul>',
	tree_foot=>'</ul>',
	subtree_head=>'<ul>',
	subtree_foot=>'</ul>',
	pre_item=>'<li>',
	post_item=>'</li>'
	pre_active_item=>'<em>',
	post_active_item=>'</em>',
	item_sep=>"\n",
	tree_sep=>"\n",
	use_count=>1,
	hide=>$hide_regex,
	root=>'Home');

Generates a list (of lists) of links of all the categories.

This provides a large number of options to customize the appearance
of the list.  The default setup is for a simple UL list, but setting
the options can enable you to make it something other than a list
altogether, or add in CSS styles or classes to make it look just
like you want.

If HTTP_REFERRER exists, this will also flag a "you were here"
in the list.

Options:

=over

=item tree_head

The string to prepend the top-level tree with.

=item tree_foot

The string to append to the top-level tree.

=item subtree_head

The string to prepend to lower-level trees.

=item subtree_foot

The string to append to lower-level trees.

=item pre_item

The string to put in front of each item.

=item post_item

The string to append to each item.

=item pre_active_item

An additional string to put in front of each "active" item, after pre_item.

The active item is the category which is the current category if the
current path is a category path.  A regular item will have a link to that
category; the active category doesn't, because we're already I<there>.

=item post_active_item

An additional string to append to each active item, before post_item.

=item item_sep

The string to separate each item.

=item tree_sep

The string to separate each tree.

=item hide

If the category matches this string, don't include it in the tree.
(defaults to 'categories_hide' config value)

=item labels

Hash containing replacement labels for one or more categories.
(defaults to 'categories_labels' config value)

=item use_count

If true, display the count of entries for that category next to that
category.

=item root

What label should we give the "root" category?
(default: Home)

=item you_were_here

String which points to the directory we just came from.
(default: '&lt;-- you were here')

=back

=cut
sub category_tree {
    my $self = shift;
    my %args = (
		tree_head=>'<ul>',
		tree_foot=>'</ul>',
		subtree_head=>'<ul>',
		subtree_foot=>'</ul>',
		pre_item=>'<li>',
		post_item=>'</li>',
		pre_active_item=>'<em>',
		post_active_item=>'</em>',
		item_sep=>"\n",
		tree_sep=>"\n",
		root=>'Home',
		you_were_here=>'&lt;-- you were here',
		use_count=>1,
		hide=>$self->{config}->{categories_hide},
		labels=>$self->{config}->{categories_labels},
		@_
	       );

    my @categories = sort keys %{$self->{categories}};
    my @list_of_lists = $self->_build_lol(categories=>\@categories,
	depth=>0,
	hide=>$args{hide});
    $args{tree_depth} = 0;
    $args{end_depth} = 0;

    # figure out what the local reference may be by looking at the referrer
    my $referrer = $ENV{HTTP_REFERER};
    my $local_ref = '';
    if ($referrer)
    {
	if ($self->{url})
	{
	    my $url = $self->{url};
	    if ($url && $referrer =~ m#${url}(.*)#)
	    {
		$local_ref = $1;
		$local_ref =~ s#[^/]+\.\w+$##;
		$local_ref =~ s#/$##;
		$local_ref =~ s#^/##;
	    }
	}
	else # guess from the host
	{
	    my $host = $ENV{HTTP_HOST};
	    if ($host && $referrer =~ m#${host}(.*)#)
	    {
		$local_ref = $1;
		$local_ref =~ s#[^/]+\.\w+$##;
		$local_ref =~ s#/$##;
		$local_ref =~ s#^/##;
	    }
	}
    }
    $args{local_ref} = $local_ref;
    my $list = $self->_traverse_lol(\%args, \@list_of_lists);
    return join('', $args{tree_head}, $list, $args{tree_foot});
} # category_tree

=head2 breadcrumb

    $links = $self->breadcrumb(
	tree_head=>'<ul>',
	tree_foot=>'</ul>',
	subtree_head=>'<ul>',
	subtree_foot=>'</ul>',
	pre_item=>'<li>',
	post_item=>'</li>'
	pre_active_item=>'<em>',
	post_active_item=>'</em>',
	item_sep=>"\n",
	tree_sep=>"\n",
	root=>'Home');

Generates a list (of lists) of links of the categories above
(and just below) the current path.

This provides a large number of options to customize the appearance
of the list.  The default setup is for a simple UL list, but setting
the options can enable you to make it something other than a list
altogether, or add in CSS styles or classes to make it look just
like you want.

Options:

=over

=item tree_head

The string to prepend the top-level tree with.

=item tree_foot

The string to append to the top-level tree.

=item subtree_head

The string to prepend to lower-level trees.

=item subtree_foot

The string to append to lower-level trees.

=item last_subtree_head

The string to prepend to the last (lowest) tree.

=item last_subtree_foot

The string to append to the last (lowest) tree.

=item pre_item

The string to put in front of each item.

=item post_item

The string to append to each item.

=item pre_active_item

An additional string to put in front of each "active" item, after pre_item.

The active item is the category which is the current category if the
current path is a category path.  A regular item will have a link to that
category; the active category doesn't, because we're already I<there>.

=item post_active_item

An additional string to append to each active item, before post_item.

=item item_sep

The string to separate each item.

=item tree_sep

The string to separate each tree.

=item hide

If the category matches this string, don't include it in the breadcrumb.
(defaults to 'categories_hide' config value)

=item labels

Hash containing replacement labels for one or more categories.
(defaults to 'categories_labels' config value)

=item root

What label should we give the "root" category?
(default: Home)

=item start_depth

The depth (from the root) at which to start the tree.
The default is zero, which means start from the root.
Most of the time that is just what one wants.

=item end_depth

The depth (from the root) at which to end the tree.  The default is
the depth of the current path ($path_depth) plus one.  This allows
one to have a breadcrumb path which looks below the current directory,
as well as above it.  If one wishes to just show the current directory
and those above it, then set this option to $path_depth.

=back

=cut
sub breadcrumb {
    my $self = shift;
    my %args = (
		tree_head=>'<ul>',
		tree_foot=>'</ul>',
		subtree_head=>'<ul>',
		subtree_foot=>'</ul>',
		last_subtree_head=>'<ul>',
		last_subtree_foot=>'</ul>',
		pre_item=>'<li>',
		post_item=>'</li>',
		pre_active_item=>'<em>',
		post_active_item=>'</em>',
		item_sep=>"\n",
		tree_sep=>"\n",
		root=>'Home',
		start_depth=>0,
		end_depth=>$self->{path}->{depth} + 1,
		hide=>$self->{config}->{categories_hide},
		labels=>$self->{config}->{categories_labels},
		@_
	       );

    my @categories = sort keys %{$self->{categories}};
    my @list_of_lists = $self->_build_lol(categories=>\@categories,
	depth=>0, match_path=>1,
	hide=>$args{hide},
	start_depth=>$args{start_depth},
	end_depth=>$args{end_depth});
    $args{tree_depth} = 0;
    my $list = $self->_traverse_lol(\%args, \@list_of_lists);
    return join('', $args{tree_head}, $list, $args{tree_foot});
} # breadcrumb

=head1 Private Methods

=head2 _build_lol

Build a list of lists of categories.

=cut
sub _build_lol {
    my $self = shift;
    my %args = (
	categories=>undef,
	depth=>0,
	start_depth=>0,
	end_depth=>0,
	match_path=>0,
	hide=>$self->{config}->{categories_hide},
	@_
    );
    my $cats_ref = $args{categories};
    my $depth = $args{depth};
    my $hide = $args{hide};

    my @list_of_lists = ();
    while (@{$cats_ref})
    {
	my $cat = @{$cats_ref}[0];
	if ($args{match_path}
	    and $self->{path}->{cat_id}
	    and !(
	     ($self->{categories}->{$cat}->{depth} < $self->{path}->{depth}
	      and $self->{path}->{cat_id} =~ /^$cat/)
	     or (
		 $self->{categories}->{$cat}->{depth} ==
		 $self->{path}->{depth}
		 and $cat eq $self->{path}->{cat_id}
		)
	     or (
		 $self->{categories}->{$cat}->{depth} >
		 $self->{path}->{depth} # child
		 and $cat =~ /^$self->{path}->{cat_id}/
		)
	    )
	   )
	{
	    shift @{$cats_ref}; # skip this one
	}
	elsif ($hide and $cat =~ /$hide/)
	{
	    shift @{$cats_ref}; # skip this one
	}
	elsif ($self->{categories}->{$cat}->{depth} < $args{start_depth})
	{
	    shift @{$cats_ref}; # skip this one
	}
	elsif ($args{end_depth}
	    and $self->{categories}->{$cat}->{depth} > $args{end_depth})
	{
	    shift @{$cats_ref}; # skip this one
	}
	elsif ($self->{categories}->{$cat}->{depth} == $depth)
	{
	    shift @{$cats_ref}; # remove this category
	    push @list_of_lists, $cat;
	}
	elsif ($self->{categories}->{$cat}->{depth} > $depth)
	{
	    push @list_of_lists, [$self->_build_lol(
		categories=>$cats_ref,
		depth=>$self->{categories}->{$cat}->{depth},
		start_depth=>$args{start_depth},
		end_depth=>$args{end_depth},
		match_path=>$args{match_path},
		)];
	}
	elsif ($self->{categories}->{$cat}->{depth} < $depth)
	{
	    return @list_of_lists;
	}
    }
    return @list_of_lists;
} # _build_lol

=head2 _traverse_lol

Traverse the list of lists of categories to produce links.

=cut
sub _traverse_lol {
    my $self = shift;
    my $args = shift;
    my $lol_ref = shift;

    my $tree_depth = $args->{tree_depth};
    my $local_ref = $args->{local_ref} || '';
    my @items = ();
    while (@{$lol_ref})
    {
	my $ll = shift @{$lol_ref};
	if (!ref $ll)
	{
	    my $cat = $ll;
	    my $item;
	    my $label;
	    if (($self->{path}->{basename} eq 'index'
		 or ($self->{path}->{type} !~ /entry$/
		     and !$self->{path}->{basename}))
		and $cat eq $self->{path}->{cat_id})
	    {
		$label = ($self->{categories}->{$cat}->{basename}
			     ? (exists
				$args->{labels}->
				{$self->{categories}->{$cat}->{basename}}
				?  $args->{labels}->
				{$self->{categories}->{$cat}->{basename}}
				: $self->{categories}->{$cat}->{pretty})
			     : $args->{root});
		$item = join('',
			     $args->{pre_item},
			     $args->{pre_active_item},
			     $label,
			     $args->{post_active_item}
			    );
	    }
	    else
	    {
		if ($self->{categories}->{$cat}->{basename})
		{
		    $label = (exists
				 $args->{labels}->
				 {$self->{categories}->{$cat}->{basename}}
				 ?  $args->{labels}->
				 {$self->{categories}->{$cat}->{basename}}
				 : $self->{categories}->{$cat}->{pretty});
		    $item = join('', $args->{pre_item},
				 '<a href="', $self->{url}, '/', $cat, '/">',
				 $label,
				 '</a>');
		}
		else
		{
		    $item = join('', $args->{pre_item},
				 '<a href="', $self->{url}, '/">',
				  $args->{root},
				 '</a>');
		}
	    }
	    if ($args->{use_count}
		&& $self->{categories}->{$cat}->{num_entries})
	    {
		$item = join('', $item, ' (',
		    $self->{categories}->{$cat}->{num_entries}, ')');
	    }
	    if ($local_ref and $local_ref eq $cat)
	    {
		$item = join(' ', $item, $args->{you_were_here});
	    }
	    if (ref $lol_ref->[0]) # next one is a list
	    {
		my $ll = shift @{$lol_ref};
		$args->{tree_depth}++; # no longer the first call
		my $sublist = $self->_traverse_lol($args, $ll);
		$item = join($args->{tree_sep}, $item, $sublist);
	    }
	    $item = join('', $item, $args->{post_item});
	    push @items, $item;
	}
	else # a list
	{
	    return $self->_traverse_lol($args, $ll);
	}
    }
    my $list = join($args->{item_sep}, @items);
    return join('',
	($tree_depth > 0
	    ? (($args->{end_depth} && $tree_depth == $args->{end_depth} )
	    ? $args->{last_subtree_head}
	    : $args->{subtree_head})
	    : ''),
	$list,
	($tree_depth > 0
	    ? (($args->{end_depth} && $tree_depth == $args->{end_depth} )
	    ? $args->{last_subtree_foot}
	    : $args->{subtree_foot})
	    : ''));
} # _traverse_lol

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::Categories

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the scripts (posy_one,
posy_static).

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

=head1 REQUIRES

    Module::Build
    Posy
    Posy::Core
    Posy::Plugin::TextTemplate

    Test::More

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2004-2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::Categories
__END__
