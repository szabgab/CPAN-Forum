package CPAN::Forum::RM::Notify;
use strict;
use warnings;

use XML::RSS::SimpleGen;
use XML::Atom::SimpleFeed;
use URI;

=head2 notify

Send out e-mails upon receiving a submission.

=cut

sub notify {
	my ( $self, $post_id ) = @_;

	my $post = CPAN::Forum::DB::Posts->get_post($post_id); # SQL
	return if not $post;

	# TODO what if it does not find it?

	my $user = sprintf( " %s %s (%s)", ( $post->{fname} || '' ), ( $post->{lname} || '' ), $post->{username} );
	my $message =
		  "$user wrote:\n\n"
		. $self->_text2mail( $post->{text} ) . "\n\n"
		. "To write a respons, access\n"
		. "http://$ENV{HTTP_HOST}/response_form/"
		. $post->{id} . "\n\n"
		. "To see the full thread, access\n"
		. "http://$ENV{HTTP_HOST}/threads/"
		. $post->{thread} . "\n\n" . "--\n"
		. "You are getting this messages from $ENV{HTTP_HOST}\n"
		. "To change your subscription information visit http://$ENV{HTTP_HOST}/mypan/\n";

	# disclaimer ?
	# X-lits: field ?

	my $subject = sprintf( "[%s] %s", $post->{group_name}, $post->{subject} ); # TODO _subject_escape ?

	my $FROM = $self->config("from");
	$self->log->debug("FROM field set to be $FROM");
	my %mail = (
		From    => $FROM,
		Subject => $subject,
		Message => $message,
	);
	$self->log->debug( Data::Dumper->Dump( [ \%mail ], ['mail'] ) );


	$self->fetch_subscriptions( \%mail, $post );
	return;
}

=head2 notify_admin

Notify the administrator about a new registration

=cut

sub notify_admin {
	my ( $self, $user ) = @_;

	my $FROM = $self->config("from");

	my $msg = "\nUsername: " . $user->{username} . "\n";

	# TODO: the admin should be able to configure if she wants to get messages on
	# every new user (field update_on_new_user)
	my $admin = CPAN::Forum::DB::Users->info_by( id => 1 ); # SQL
	my %mail = (
		To      => $admin->{email},
		From    => $FROM,
		Subject => "New Forum user: " . $user->{username},
		Message => $msg,
	);
	$self->log->debug( Data::Dumper->Dump( [ \%mail ], ['mail'] ) );
	$self->_my_sendmail(%mail);
}

=head2 rss

Provide RSS feed
/rss/all  latest N entries
/rss/threads  latest N active threads
/rss/dist/Distro-Name  latest N entries of that distro name
/rss/author/PAUSEID

/rss/tags latest N tags

=cut

sub rss {
	my ($self) = @_;
	$self->_feed('rss');
}

=head2 atom

adom feed

=cut

sub atom {
	my ($self) = @_;
	$self->_feed('atom');
}

sub _feed {
	my ( $self, $type ) = @_;

	die "invalid _feed call '$type'"
		if not defined $type
			or ( $type ne 'rss' and $type ne 'atom' );

	my $limit = $self->config("${type}_size") || 10;
	my $it = $self->get_feed($limit);

	my $url  = "http://$ENV{HTTP_HOST}";
	my $call = "_generate_$type";

	my @params = @{ $self->query->param("path_parameters") };
	my $content;
	if ( $params[0] eq 'tags' ) {
		$content = 'tags';
	}

	return $self->$call( $url, $it, $content );
}

sub _generate_atom {
	my ( $self, $url, $it, $type ) = @_;


	my $feed = XML::Atom::SimpleFeed->new(
		title  => 'CPAN::Forum',
		link   => "$url/",
		author => 'admin@cpanforum.com',
		id     => "$url/",
	);

	if ( $it and @$it ) {
		foreach my $post (@$it) {
			my $title = sprintf "[%s] %s", $post->{group_name}, $post->{subject};
			my $author = {
				name => sprintf(
					"%s %s (%s)",
					( $post->{user_fname} || '' ),
					( $post->{user_lname} || '' ),
					$post->{user_username}
				),
				uri => "$url/users/" . $post->{user_username},
			};
			my $link = "$url/posts/" . $post->{id};
			$feed->add_entry(
				author => $author,
				title  => $title, # TODO _subject_escape ?
				link   => $link,
				id     => $link,
			);
		}
	} else {
		$feed->add_entry(
			author => 'No author yet',
			title  => 'No posts yet',
			link   => "$url/",
			id     => "$url/",
		);
	}

	$self->header_props( -type => 'application/atom+xml' );

	return $feed->as_string();
}

sub _generate_rss {
	my ( $self, $url, $it, $type ) = @_;

	my $q = $self->query;

	my $rss = XML::RSS::SimpleGen->new( "$url/", "CPAN Forum", "Discussing Perl CPAN modules" );
	$rss->language('en');

	# TODO: replace this e-mail address with a configurable value
	$rss->webmaster('admin@cpanforum.com');

	if ( $it and @$it ) {
		if ( $type and $type eq 'tags' ) {
			foreach my $post (@$it) {
				my $title = sprintf "%s on %s at %s", $post->{tag}, $post->{dist}, $post->{stamp};

				#POSIX::strftime("%Y%m%d %H:%S", localtime($post->{stamp}));
				my $uri = URI->new( "$url/tags/name/" . $post->{tag} );
				$rss->item( $uri->as_string, $title );
			}
		} else {
			foreach my $post (@$it) {
				my $title = sprintf "[%s] %s", $post->{group_name}, $post->{subject};
				$rss->item( "$url/posts/" . $post->{id}, $title ); # TODO _subject_escape ?
			}
		}
	} else {

		# TODO: maybe we should put a link here to search that module ot that
		# PAUSEID?
		$rss->item( "$url/", "No posts yet" );
	}

	$self->header_props( -type => 'application/rss+xml' );

	return $rss->as_string();
}


# URL: Both /rss/...  and /atom/.... are serverd by this
sub get_feed {
	my ( $self, $limit ) = @_;

	my @params = @{ $self->query->param("path_parameters") };

	return [] if not @params;

	# URL: /rss/dist/CPAN-Forum
	# URL: /atom/dist/CPAN-Forum
	if ( $params[0] eq 'dist' ) {
		my $dist = $params[1] || '';
		$self->log->debug("rss of dist: '$dist'");
		return CPAN::Forum::DB::Posts->search_post_by_groupname( $dist, $limit ); # SQL
	}

	# URL: /rss/author/SZABGAB  ( /rss/author/szabgab also works )
	if ( $params[0] eq 'author' ) {
		my $pauseid = uc( $params[1] ) || '';
		if ($pauseid) {
			$self->log->debug("rss of author: '$pauseid'");
			return CPAN::Forum::DB::Posts->search_post_by_pauseid( $pauseid, $limit ); # SQL
		}
	}

	# URL /rss/all     - latest posts
	if ( $params[0] eq 'all' ) {
		return CPAN::Forum::DB::Posts->retrieve_latest($limit);                        # SQL
	}

	# URL /rss/threads - latest threads (questions)
	if ( $params[0] eq 'threads' ) {
		return CPAN::Forum::DB::Posts->search_latest_threads($limit);                  # SQL
	}

	# URL /rss/tags  - latest tags with timestamp
	if ( $params[0] eq 'tags' ) {
		return CPAN::Forum::DB::Tags->retrieve_latest($limit);                         # SQL
	}

	return;
}

=head2 _text2mail

replace the markup used in the posting by things we can use in 
e-mail messages.

=cut

sub _text2mail {
	return $_[1];
}


1;

