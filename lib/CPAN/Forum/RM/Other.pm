package CPAN::Forum::RM::Other;
use strict;
use warnings;

our $VERSION = '0.17';

use CPAN::Forum::DBI ();
use CPAN::Forum::DB::Posts ();
use CPAN::Forum::DB::Tags ();

=head2 about

About box with some statistics.

=cut

sub about {
	my $self = shift;

	my %params = (
		distro_cnt       => CPAN::Forum::DBI->count_rows_in('groups'),
		posts_cnt        => CPAN::Forum::DBI->count_rows_in('posts'),
		users_cnt        => CPAN::Forum::DBI->count_rows_in('users'),
		subscription_cnt => CPAN::Forum::DBI->count_rows_in('subscriptions'),
		tag_cloud_cnt    => CPAN::Forum::DBI->count_rows_in('tag_cloud'),
		version          => $self->version,
	);

	# number of posts per group name, can create some xml feed from it that can
	# be used by search.cpan.org and Kobes to add a number of posts next to the link
	#select count(*),groups.name from posts, groups where groups.id=gid group by gid;
	#
	#count posts for a specific group:
	#select count(*) from posts, groups where groups.id=gid and groups.name="CPAN-Forum";

	return $self->tt_process('pages/about.tt', \%params);
}


sub privacy_policy {
	return $_[0]->tt_process('pages/privacy_policy.tt');
}

=head2 stats

The stats run-mode showing some statistics
(actually the 50 busiest groups)

=cut

sub stats {
	my $self        = shift;
	my $modules_cnt = 50;
	my $groups      = CPAN::Forum::DB::Posts->stat_posts_by_group($modules_cnt);
	my %params = (
		modules_cnt => $modules_cnt,
		groups      => $groups,
	);

	my $users_cnt = 50;
	my $top_users = CPAN::Forum::DB::Posts->stat_posts_by_user($users_cnt);
	$params{users_cnt} = $users_cnt;
	$params{users}     = $top_users;

	my $tagging_users_cnt = 20;
	my $top_tagging_users = CPAN::Forum::DB::Tags->stat_tags_by_user($tagging_users_cnt);
	$params{tagging_users_cnt} = $tagging_users_cnt;
	$params{tagging_users}     = $top_tagging_users;

	return $self->tt_process('pages/stats.tt', \%params);
}

=head2 faq

Show FAQ

=cut

sub faq {
	return $_[0]->tt_process('pages/faq.tt');
}

sub help {
	return $_[0]->tt_process('pages/help.tt');
}

sub site_is_closed {
	return $_[0]->tt_process('pages/site_is_closed.tt');
}


1;

