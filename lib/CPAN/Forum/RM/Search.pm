package CPAN::Forum::RM::Search;
use strict;
use warnings;

our $VERSION = '0.17';

use CPAN::Forum::DB::Posts ();
use CPAN::Forum::DB::Groups ();
use CPAN::Forum::DB::Users ();

# ->_search_results( {where => {}, page => $n});
sub _search_results {
	my ( $self, $params ) = @_;

	$params->{per_page} = $self->config("per_page");

	my $pager   = CPAN::Forum::DB::Posts->mysearch($params);
	my $results = $pager->{results};

	#$self->log->debug(Data::Dumper->Dump([$results], ['results']));
	return if not $pager->{total_entries};

	$self->log->debug("number of entries: total=$pager->{total_entries}");
	my $data = $self->build_listing($results);
	my %params = (
		messages      => $data,
		total         => $pager->{total_entries},
		previous_page => $pager->{previous_page},
		next_page     => $pager->{next_page},
		first_entry   => $pager->{first_entry},
		last_entry    => $pager->{last_entry},
		first_page    => ($pager->{current_page} != 1 ? 1 : 0),
		last_page     => ($pager->{current_page} != $pager->{last_page}) ? $pager->{last_page} : 0,
	);

	return \%params;
}

sub module_search_form {
	my ( $self, $errors ) = @_;
	my $t = $self->load_tmpl("module_search_form.tmpl");
	$t->param( $_ => 1 ) foreach @$errors;
	$t->output;
}

sub module_search {
	my ($self) = @_;

	my $q   = $self->query;
	my $txt = $q->param("q");
	$txt =~ s/^\s+|\s+$//g;

	# remove taint if there is
	if ( $txt =~ /^([\w:.%-]+)$/ ) {
		$txt = $1;
	} else {
		$self->log->debug("Tained search: $txt");
	}

	if ( not $txt ) {
		return $self->module_search_form( ['invalid_search_term'] );
	}
	$self->log->debug("group name search term: $txt");
	$txt =~ s/::/-/g;
	$txt = '%' . $txt . '%';

	my $groups_hr   = CPAN::Forum::DB::Groups->groups_by_name($txt);
	my @group_names = values %$groups_hr;
	my @group_ids   = keys %$groups_hr;
	if ( not @group_names ) {
		return $self->module_search_form( ['no_module_found'] );
	}

	#$self->log->debug("GROUP NAMES: @group_names");

	my $t = $self->load_tmpl(
		"module_select_form.tmpl",
	);
	$t->param( "group_selector" => $self->_group_selector( \@group_names, \@group_ids ) );
	$t->output;
}

sub search {
	my ($self) = @_;
	my $q = $self->query;
	my $name = $q->param("name") || '';
	my $what = $q->param("what") || '';
	$name =~ s/^\s+|\s+$//g;

	# kill the taint checking (why do I use taint checking if I kill it then ?)
	if ( $name =~ /(.*)/ ) { $name = $1; }
	$name =~ s/::/-/g if $what eq "module";

	my $it;

	if ( not $what and not $name ) {
		$what = $self->session->param('search_what');
		$name = $self->session->param('search_name');
	}

	$self->session->param( search_what => $what );
	$self->session->param( search_name => $name );

	my $params;
	if ( $what and $name ) {
		if ( $what eq "module" or $what eq "pauseid" ) {
			$params = $self->_search_modules( $name, $what );
		} elsif ( $what eq "user" ) {
			$params = $self->_search_users( $name, $what );
		} else {
			$params = $self->_search_posts( $name, $what );
		}
	}
	return $self->tt_process('pages/search.tt', $params);
}

# $what: module or pauseid
sub _search_modules {
	my ( $self, $name, $what ) = @_;

	my %params;
	my $groups;
	if ( $what eq "module" ) {
		$groups = CPAN::Forum::DB::Groups->names_by_name($name);
	} else {
		$groups = CPAN::Forum::DB::Groups->names_by_pauseidstr( uc $name );
		$params{pauseid_name} = uc $name;
	}
	$params{groups} = $groups;
	$params{$what} = 1;
	$params{no_results} = @$groups ? 0 : 1;
	return \%params;
}

sub _search_users {
	my ( $self, $name, $what ) = @_;

	my $users = CPAN::Forum::DB::Users->list_users_like( lc($name) );
	my %params = (
		users => $users,
		$what => 1,
		no_results => (@$users ? 0 : 1),
	);
	return \%params;
}

sub _search_posts {
	my ( $self, $name, $what ) = @_;

	my $q = $self->query;

	my %where;
	if ( $what eq "subject" ) { %where = ( subject => { 'LIKE', '%' . $name . '%' } ); }
	if ( $what eq "text" )    { %where = ( text    => { 'LIKE', '%' . $name . '%' } ); }
	$self->log->debug( "Search 1: " . join "|", %where );
	if (%where) {

		$self->log->debug( "Search 2: " . join "|", %where );

		my $page = $q->param('page') || 1;
		#$t->param( $what => 1 );
		#$self->_search_results( { where => \%where, page => $page } );
	}
	return {no_results => 1};
}

1;

