package CPAN::Forum::RM::Posts;
use strict;
use warnings;

our $VERSION = '0.20';

use CPAN::Forum::DB::Groups ();
use CPAN::Forum::DB::Posts ();
use CPAN::Forum::DB::Users ();
use CPAN::Forum::Markup ();
use CPAN::Forum::Tools ();

my $SUBJECT    = qr{[\w .:~!@#\$%^&*\()+?><,'";=-]+};

=head2 new_post

Showing the new post page. (Alias of C<posts()>)

=cut

sub new_post {
	posts(@_);
}

=head2 response_form

Showing the response form. (Alias of C<posts()>)

=cut

sub response_form {
	posts(@_);
}


=head2 posts

Show a post, the editor and a preview - whichever is needed.

=cut

sub posts {
	my ( $self, $preview, $errors ) = @_;
	my $q = $self->query;

	my %params = map { $_ => 1 } @$errors;

	my $rm = $self->get_current_runmode();
	my $request = $self->session->param('request');
	if ($request) {
		$rm = $request;
	}

	my $new_group    = "";
	my $new_group_id = "";

	if ( $rm eq "new_post" ) {
		$new_group = ${ $self->param("path_parameters") }[0] || "";
		$new_group_id = $q->param('new_group') if $q->param('new_group');

		if ($new_group) {
			if ( $new_group =~ /^([\w-]+)$/ ) {
				$new_group = $1;
				my ($gr) = CPAN::Forum::DB::Groups->info_by( name => $new_group );
				if ($gr) {
					$new_group_id = $gr->{id};
				} else {
					return $self->internal_error(
						"Group '$new_group' was not in database",
					);
				}
			} else {
				return $self->internal_error(
					"Bad regex for '$new_group' ?",
				);
			}
		} elsif ($new_group_id) {
			my ($gr) = CPAN::Forum::DB::Groups->info_by( id => $new_group_id );
			if ($gr) {
				$new_group = $gr->{name};
			} else {
				return $self->internal_error(
					"Group '$new_group_id' was not in database",
				);
			}
		} elsif ( $q->param('q') ) {

			# process search later
		} else {

			# TODO should be called whent the module_search is ready
			return $self->module_search_form();
		}
	}
	if ( $rm eq "process_post" ) {
		$new_group_id = $q->param("new_group_id");
		if ( not $new_group_id ) {
			return $self->internal_error(
				"Missing new_group_id.",
			);
		}

		if ( $new_group_id =~ /^(\d+)$/ ) {
			$new_group_id = $1;
			my ($grp) = CPAN::Forum::DB::Groups->info_by( id => $new_group_id );
			if ($grp) {
				$new_group = $grp->{name};
			} else {
				return $self->internal_error(
					"Bad value for new_group (id) '$new_group_id' ?",
				);
			}
		} else {
			return $self->internal_error(
				"Bad value for new_group (id) '$new_group_id' ?",
			);
		}
	}

	my $title  = ""; # of the page
	my $editor = 0;
	$params{editor} = 1 if grep { $rm eq $_ } (qw(process_post new_post response_form));


	my $id = $q->param("id"); # there was an id
	if ( $rm eq "response_form" or $rm eq "posts" ) {
		$id = ${ $self->param("path_parameters") }[0] if ${ $self->param("path_parameters") }[0];
	}
	$id ||= $q->param("new_parent");
	if ($id) {                # Show post
		$params{new_parent} = $id;
		if ($id !~ /^\d+$/) {
			$self->log->warning("User requested '/posts/$id' but that's not a numeric id");
			return $self->notes('invalid_request');
		}
		my $post = CPAN::Forum::DB::Posts->get_post($id);
		if ( not $post ) {
			$self->log->warning("User requested '/posts/$id' but we could not find it in the database");
			return $self->notes('no_such_post');
		}
		my $thread_count = CPAN::Forum::DB::Posts->count_thread( $post->{thread} );
		if ( $thread_count > 1 ) {
			$params{thread_id}    = $post->{thread};
			$params{thread_count} = $thread_count;
		}
		$post->{responses} = CPAN::Forum::DB::Posts->list_posts_by( parent => $post->{id} );

		my $post_data = CPAN::Forum::Tools::format_post($post);
		$params{post} = $post_data;

		#       (my $dashgroup = $post->gid) =~ s/::/-/g;
		#       $params{dashgroup}    = $dashgroup;
		my $new_subject = $q->param('new_subject');
		if (not $new_subject) {
			$new_subject = $post->{subject};
			if ( $new_subject !~ /^\s*re:\s*/i ) {
				$new_subject = "Re: $new_subject";
			}
		}

		$params{new_subject} = CPAN::Forum::Tools::_subject_escape($new_subject);
		$params{title}       = CPAN::Forum::Tools::_subject_escape( $post->{subject} );

		my $group = CPAN::Forum::DB::Groups->info_by( id => $post->{gid} );
		$new_group    = $group->{name};
		$new_group_id = $group->{id};
	}

	#$params{group_selector} = $self->_group_selector($new_group, $new_group_id);
	$params{new_group}    = $new_group;
	$params{new_group_id} = $new_group_id;
	$params{new_text}     = CGI::escapeHTML( $q->param("new_text") );

	# for previewing purposes:
	# This is funky, in order to use the same template for regular show of a message and for
	# the preview facility we create a loop around this code for the preview page (with hopefully
	# only one iteration in it) The following hash is in preparation of this internal loop.
	if ( $preview ) {
		my %preview;
		$preview{subject}  = CPAN::Forum::Tools::_subject_escape( $q->param("new_subject") || '' );
		$preview{text}     = CPAN::Forum::Tools::_text_escape( $q->param("new_text") || '' );
		$preview{parentid} = $q->param("new_parent")                      || "";

		#       $preview{thread_id}  = $q->param("new_text")    || "";
		$preview{postername} = $self->session->param("username");
		$preview{date}       = localtime;
		$preview{id}         = "TBD";

		$params{preview} = \%preview;
	}

	$params{new_subject} ||= CPAN::Forum::Tools::_subject_escape($q->param("new_subject"));
	$params{group} = $new_group if $new_group;

	return $self->tt_process('pages/posts.tt', \%params);
}


=head2 process_post

Process a posting, that is take the values from the CGI object, check if they
are acceptable and try to add them to the database. If anything bad happens,
give an error message preferably by filling out the form again.

=cut

sub process_post {
	my $self = shift;
	my $q    = $self->query;
	my @errors;
	my $parent = $q->param("new_parent");

	my $parent_post;
	if ($parent) { # assume response
		$parent_post = CPAN::Forum::DB::Posts->get_post($parent);
		push @errors, "bad_thing" if not $parent_post;
	} else {                                                      # assume new post
		if ( $q->param("new_group_id") ) {
			push @errors, "bad_group" if not CPAN::Forum::DB::Groups->info_by( id => $q->param("new_group_id") );
		} else {
			push @errors, "no_group";
		}
	}

	my $new_subject = $q->param("new_subject");
	my $new_text    = $q->param("new_text");

	push @errors, "no_subject" if not $new_subject;
	push @errors, "invalid_subject" if $new_subject and $new_subject !~ m{^$SUBJECT$};

	push @errors, "no_text" if not $new_text;
	push @errors, "subject_too_long" if $new_subject and length($new_subject) > 80;

	my $preview_button = $q->param("preview_button");
	my $submit_button  = $q->param("submit_button");
	if ( not @errors and $submit_button ) {
		my $last_post = CPAN::Forum::DB::Posts->get_latest_post_by_uid( $self->session->param('uid') );
		  # TODO, maybe also check if the post is the same as the last post to avoid duplicates
		if ($last_post) {
			if ( $last_post->{text} eq $new_text ) {
				push @errors, "duplicate_post";
			} elsif (CPAN::Forum::DB::Posts->post_within_limit( $self->session->param('uid'), $self->config("flood_control_time_limit") ) ) {
				push @errors, "flood_control";
			} 
		}
	}

	return $self->posts( undef, \@errors ) if @errors;


	# There will be two buttons, one for Submit and one for Preview.
	# We will save the message only if the Submit button was pressed.
	# When the editor first displayed and every time if an error was caught this button will be hidden.

	my $markup = CPAN::Forum::Markup->new();
	my $result = $markup->posting_process($new_text);
	if ( not defined $result ) {
		push @errors, "text_format";
		return $self->posts( undef, \@errors );
	}


	if ($preview_button) {
		return $self->posts( "preview", [] );
	}
	if ( not $submit_button ) {
		return $self->internal_error(
			"Someone sent in a form without the Preview or Submit button",
		);
	}

	my $username = $self->session->param("username");
	my $user = CPAN::Forum::DB::Users->info_by( username => $username );
	if ( not $user ) {
		return $self->internal_error("Unknown username: '$username'");
	}


	my %data = (
		uid     => $user->{id},
		gid     => ( $parent_post ? $parent_post->{gid} : $q->param("new_group_id") ),
		subject => $q->param("new_subject"),
		text    => $new_text,
	);
	my $post_id = eval { CPAN::Forum::DB::Posts->add_post( \%data, $parent_post, $parent ); };
	if ($@) {

		#push @errors, "subject_too_long" if $@ =~ /subject_too_long/;
		if ( not @errors ) {
			return $self->internal_error(
				"UNKNOWN_ERROR: $@",
			);
		}
		return $self->posts( undef, \@errors );
	}

	#$self->notify($post_id);

	$self->home;
}



1;

