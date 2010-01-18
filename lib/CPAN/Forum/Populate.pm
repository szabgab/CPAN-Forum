package CPAN::Forum::Populate;

use Moose;

our $VERSION = '0.18';

use autodie;
use CPAN::Mini ();
use Cwd        ();
use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use File::Find::Rule ();
use File::HomeDir    ();
use File::Path qw(rmtree mkpath);
use File::Temp qw(tempdir);
use Parse::CPAN::Packages;


use CPAN::Forum::Pod;

use CPAN::Forum::DBI;
use CPAN::Forum::DB::Groups;
use CPAN::Forum::DB::Authors;

=head1 NAME

CPAN::Forum::Populate - populate the database by date from CPAN and other sources

=head1 SYNOPSIS

  my $p = CPAN::Forum::Populate->new(\%opts);
  
  %opts can contain
     mirror => 

  $p->run;

 
  $p->mirror_cpan();

  # tell what kind of processing to do

  # start the processing on some of the file
  $p->process;
  

=head1 DESCRIPTION

=cut

has 'mirror'  => ( is => 'ro' );
has 'process' => ( is => 'ro' );
has 'html'    => ( is => 'ro' );
has 'yaml'    => ( is => 'ro' );
has 'ppi'     => ( is => 'ro' );


has 'dir'         => ( is => 'rw' );
has 'cpan'        => ( is => 'rw' );
has 'all_modules' => ( is => 'rw' );
has 'file'        => ( is => 'rw' );
has 'dist'        => ( is => 'rw' );
has 'version'     => ( is => 'rw' );
has 'vversion'    => ( is => 'rw' );
has 'source_path' => ( is => 'rw' );
has 'html_path'   => ( is => 'rw' );
has 'distinfo'    => ( is => 'rw' );
has 'cwd'         => ( is => 'rw' );
has 'localcpan'   => ( is => 'rw' );

=pod

=head2 mirror_cpan

Should be able to mirror a small subsection using CPAN::Mini or a full CPAN::Mini or a full CPAN mirror.

=cut

sub mirror_cpan {
	my ($self) = @_;

	return if not $self->mirror;

	# TODO implement full CPAN mirror (using rsync?)
	die "Full CPAN mirror not yet implemented, use mini of filename\n" if $self->mirror eq 'cpan';

	debug("Get CPAN");
	my $cpan = $self->cpan;

	#die $cpan;
	my $cpan_dir = $self->localcpan;
	my $verbose  = 0;
	my $force    = 1;

	my @filter;
	if ( $self->mirror ne 'mini' ) {

		# comment out so won't delete mirror accidentally
		open my $fh, '<', $self->mirror;
		my @modules = <$fh>; # TODO check formatting
		chomp @modules;
		close $fh;
		$self->all_modules( \@modules );
		@filter = ( path_filters => [ sub { $self->filter(@_) } ] );
	}
	CPAN::Mini->update_mirror(
		remote => $cpan,
		local  => $cpan_dir,
		trace  => $verbose,
		force  => $force,
		@filter,
	);

	return;
}
{
	my %modules;
	my %seen;

	sub filter {
		my ( $self, $path ) = @_;

		return $seen{$path} if exists $seen{$path};

		if ( not %modules ) {
			foreach my $name ( @{ $self->all_modules } ) {
				$name =~ s/::/-/g;
				$modules{$name} = 1;
			}
		}
		foreach my $module ( keys %modules ) {
			if ( $path =~ m{/$module-v?\d} ) { # Damian use a v prefix in the module name
				print "Mirror: $path\n";
				return $seen{$path} = 0;
			}
		}

		#die Dumper \%modules;
		#warn "@_\n";
		return $seen{$path} = 1;
	}
}

=pod

=head2 process

=cut

sub process_files {
	my ($self) = @_;
	return if not $self->process;

	CPAN::Forum::DBI->myinit();

	if ( $self->process eq 'all' ) {
		my $cpan_dir = $self->localcpan;
		my $tmp      = tempdir( CLEANUP => 1 );
		my $src      = "$cpan_dir/modules/02packages.details.txt.gz";
		my $copy     = "$tmp/02packages.details.txt.gz";
		my $txt      = "$tmp/02packages.details.txt";
		copy $src, $copy or die ("Could not copy '$src' to '$copy'");
		system("gunzip $copy") and die;

		my $p = Parse::CPAN::Packages->new($txt);

		my $cnt;
		foreach my $d ( $p->latest_distributions ) {
			$cnt++;

			# skip scripts
			if ( not $d->prefix or $d->prefix =~ m{^\w/\w\w/\w+/scripts/} ) {
				error("no prefix line $cnt");
				next;
			}

			my $name = $d->dist;
			if ( not $name ) {
				error("No name: line: $cnt prefix:" . $d->prefix);
				next;
			}

			# for now skip names that start with lower case
			#next LINE if $name =~ /^[a-z]/;

			$self->file( $d->prefix );
			$self->distinfo($d);
			$self->process_file();
			debug("Done");
#<STDIN>;
		}
	} elsif ( $self->process eq 'new' ) {
		die '--process new   not yet implemented';
	} else {
		$self->file( $self->process );
		$self->process_file();
	}

	return;
}


sub process_file {
	my ($self) = @_;

	eval {
		$self->unzip_file;
		$self->generate_html;
		$self->update_meta_data;
		$self->process_ppi;
	};
	if ($@) {
		error($@);
	}

	return;
}


sub unzip_file {
	my ($self) = @_;

	my $src = $self->source_dir;
	mkpath($src) if not -e $src;

	my $file = $self->file;

	info("Processing $file");
	# file look like this:
	# R/RJ/RJBS/CPAN-Mini-0.576.tar.gz
	# A/AA/AADLER/Games-LogicPuzzle-0.20.zip
	if ( $file !~ m{^  (\w)/   (\1\w)/    (\2\w+)/     ([\w-]+)-(v?)([\d.]+)   \.   (tar\.gz|tgz|zip|bz2)   $}x ) {
		die "File '$file' is not a recognized format\n";
	}
	my $pauseid = $3;
	my $package = $4;
	my $version = $6;
	my $vversion = "$5$version";

	debug("PAUSE '$pauseid' package  '$package' version '$version' vversion '$vversion'");
	my $filename = basename($file);
	my $root     = '';
	my $path     = dirname($file);
	$self->dist($package);
	$self->version($version);
	$self->vversion($vversion);

	my $target_parent_dir = "$src/$path/";
	mkpath($target_parent_dir);

	$self->source_path("$target_parent_dir/$package-$vversion");
	my $dir             = $self->dir;
	my $html_parent_dir = "$dir/html/$path";
	$self->html_path("$html_parent_dir/$package-$vversion");

	return if -e $self->source_path;

	my $cpan_dir = $self->localcpan;



	my $full_path = "$cpan_dir/authors/id/$file";
	if ( not -e $full_path ) {
		die "File '$full_path' does not exist\n";
	}

	# TODO unzip within a temp directory in case the zipped file does not have a main directory in it?
	# TODO: having more control with Archive::Zip or similar module?
	my $tmp = tempdir( CLEANUP => 1 );

	# prepare for the case if the file does not have subdirectory in there:
	my $ddir = "$tmp/$package-$vversion";
	mkdir $ddir;
	chdir $ddir;

	debug("ddir $ddir");
	if ( substr( $file, -7 ) eq '.tar.gz' or substr( $file, -4 ) eq '.tgz' ) {
		_system("tar xzf $full_path");
	} elsif ( substr( $file, -4 ) eq '.zip' ) {
		_system("unzip $full_path");
	} elsif ( substr( $file, -4 ) eq '.bz2' ) {
		_system("tar xjf $full_path");
	} else {
		die "Unrecognized file '$file'\n";
	}

	# TODO: check if there are other files, look how CPANTS checks if the file can be opened correctly

	if (not -d "$package-$vversion") {
		error("Could not find $package$vversion subdir");
		chdir '..';
	}
	debug("move($package-$vversion, " . $self->source_path . ")");
	debug(Cwd::cwd);
	system "mv $package-$vversion " . $self->source_path;
	#<STDIN>;
	chdir $self->cwd;

	return;
}


sub generate_html {
	my ($self) = @_;

	return if not $self->html;


	my $pod = CPAN::Forum::Pod->new;
	my $html;
	$pod->output_string( \$html );

	my $src  = $self->source_path;
	my $dest = $self->html_path;
	debug("Generate HTML for $src");
	die "No source path" if not $src;
	die "Source path '$src' does not exist'" if not -d $src;

	# TODO, deal with packages where the main module is not in the lib/ directory (e.g. id/A/AA/AADLER/Games-LogicPuzzle-0.20.zip )
	foreach my $file ( File::Find::Rule->file->name( '*.pm', '*.pod' )->relative->in("$src/lib") ) {
		$html = '';
		debug("   POD processing $file");
		$pod->parse_file("$src/lib/$file");
		if ( $pod->content_seen ) {
			$file =~ s/\.\w+$/.html/;
			my $outfile = "$dest/lib/$file";
			mkpath( dirname($outfile) );
			if ( open my $out, '>', $outfile ) {
				print $out $html;
			}
		}
	}

	# create symbolic link

	my $dir = $self->dir;
	mkpath("$dir/dist/");
	my $dist = $self->dist;
	unlink "$dir/dist/$dist" or die $!;
	debug("Unlink $dir/dist/$dist");
	_system("ln -s $dest $dir/dist/$dist");

	return;
}

# TODO: find a better name  --meta is not good because Moose does not like it
# --yaml is not good because it is not only yaml
# maybe --db ??
sub update_meta_data {
	my ($self) = @_;
	return if not $self->meta;

	my $d       = $self->distinfo;
	my $name    = $d->dist;
	my $pauseid = ( $d->cpanid() || "" );
	my $p;
	if ($pauseid) {
		eval { $p = CPAN::Forum::DB::Authors->find_or_create($pauseid); };
		if ($@) {
			error("Could not find or create pause id '$pauseid' for '$name'\n$@");
			return;
		}
	}
	if ( not $p ) {
		error("No PAUSEID?" . $d->prefix);
		return;
	}

	my %new = (
		version => ( $d->version() || "" ),
		pauseid => $p->{id},
	);
	my ($g) = CPAN::Forum::DB::Groups->get_data_by_name($name);
	if (%$g) {
		my $changed;
		foreach my $field (qw(version pauseid)) {

			#print "$name\n";
			#print "NEW: $new{$field}\n";
			#print "OLD: " . $g->$field, "\n";
			#<STDIN>;
			if ( not defined $g->{$field} or $g->{$field} ne $new{$field} ) {

				#print "change\n";
				#$message{$field} .= sprintf "The %s of %s has changed from %s to %s\n",
				#		$field, $name, ($g->{$field} || ""), $new{$field};
				$g->{$field} = $new{$field};
				$changed++;
			}
		}

		if ($changed) {
			CPAN::Forum::DB::Groups->update_data_by_name( $name, $g );
		}
		return;
	}

	#$message{new} .= sprintf "Creating %s   %s\n", $name, $new{version}, $pauseid;

	debug("Adding group '$name'");
#	<STDIN>;
	eval {
		my $g = CPAN::Forum::DB::Groups->add(
			name    => $name,
			gtype   => $CPAN::Forum::DBI::group_types{Distribution},
			version => $new{version},
			pauseid => $new{pauseid},
		);
	};
	if ($@) {
		error("Could not add dist '$name'\n$@");
	}
	return;
}

sub process_ppi {
	my ($self) = @_;
	return if not $self->ppi;
	return;
}

=pod

=head2 run

=cut

sub run {
	my ($self) = @_;

	$self->setup;
	$self->mirror_cpan;
	$self->process_files;
	chdir $self->cwd;

	return;
}

sub setup {
	my ($self) = @_;

	$self->cwd( Cwd::cwd() );
	if ( not $self->dir ) {
		my $home = File::HomeDir->my_home;
		$self->dir("$home/.cpanforum");
	}
	debug( "directory: " . $self->dir );
	if (not $self->localcpan) {
		$self->localcpan( $_[0]->dir . '/cpan_mirror' );
	}

	# TODO allow --cpan command line flag?
	if ( not $self->cpan ) {
		$self->cpan('http://cpan.hexten.net/');
	}

	return;
}

sub source_dir { return $_[0]->dir . '/src'; }

sub _system {
	my ($cmd) = @_;
	debug($cmd);
	system($cmd);
	return;
}

sub debug {
	print "DEBUG: @_\n";
}
sub info {
	print "INFO:  @_\n";
}
sub error {
	print "ERROR: @_\n";
}

=head1

=head1 LICENSE

Copyright 2004-2010, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut



1;
