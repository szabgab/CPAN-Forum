package CPAN::Forum::Build;
use warnings;
use strict;
use File::Copy;
use File::Path;
use Data::Dumper;

use FindBin qw($Bin);

#my $root;
use base "Module::Build";
#sub create_build_script {
#	my $self = shift;
#	$root = shift;
#
#	$self->SUPER::create_build_script(@_);
#}

sub ACTION_build {
	my $self = shift;
#	$self->SUPER::ACTION_build(@_);
	
	system "rm -rf blib";
	copy_tree(from => ".", dir => "blib");
	replace_sh_bang("$Bin/blib", <blib/bin/* blib/www/cgi/*>);
}

sub ACTION_install {
	my $self = shift;
	my $dir = $self->{args}->{dir};
	
	if (not defined $dir) {
	   die "Usage: $0 install dir=/path/to/install\n";
	}

	copy_tree(from => "blib", dir => $dir);
	replace_sh_bang("$dir", <$dir/bin/* $dir/www/cgi/*>);
}

sub ACTION_test {
	my $self = shift;
	my $p = $self->{properties};

	local @INC = (
		File::Spec->catdir($p->{base_dir}, "blib", 'modules'),
		@INC);
	$self->SUPER::ACTION_test(@_);
}

sub ACTION_cover {
    my $self = shift;
    $self->depends_on('build');
    system qw( cover -delete );

    # sometimes we get failing tests, which makes Test::Harness
    # die.  catch that
    eval {
        #local $ENV{PERL5OPT} = "-MDevel::Cover=-summary,0";
        local $ENV{PERL5OPT} = "-MDevel::Cover";
        $self->ACTION_test(@_);
    };
    system qw( cover -report html );
}


# Replace the sh_bang line on each one of the scripts in the build directory
# keeping the parameters
sub replace_sh_bang {
	my ($dir, @files) = @_;

	foreach my $file (@files) {
		open my $fh, "<", $file or die "Could not open '$file' for reading $!\n";
		my @data = <$fh>;
		close $fh;
		#$data[0] =~ s{#![\w/]*}{#!$^X};

		foreach my $line (@data) {
			if ($line =~ /use constant ROOT =>/) {
				$line =  "use constant ROOT =>  '$dir';\n"
			}
		}
		open my $wh, ">", $file or die "Could not open '$file' for writing $!\n";
		print $wh @data;
		close $wh
	}
}


# copying the files needed for the installation
# parameters: 
# dir =>  DIR, 
# verbose => 1
sub copy_tree {
	my %args = @_;
	return if not defined $args{dir};
	return if not defined $args{from};

	my $dir = $args{dir};
	my $from = $args{from};

	if (not -e $dir) {
    		mkpath $dir or die "Cannot create directory '$dir' $!\n";
	}

	open my $m, "MANIFEST" or die "Could not find the MANIFEST file $!\n";
	while (my $line = <$m>) {
		next if $line !~ /\S/;

		#my ($file, $skip) = split /\s+/, $line;
		my $file = $line;
		chomp $file;
		# hard coded skip list
		my $skip = 0;
		$skip = 1 if $file =~ m{^t/} or $file !~ m{/} or $file eq "bin/install.pl";
    
		if ($skip) {
			print "Skiping '$file'\n" if $args{verbose};
			next;
		}

		my $subdir = $file;
		$subdir =~ s@[^/]+$@@;
		if ($subdir and not -e "$dir/$subdir") {
			print "Making $dir/$subdir\n" if $args{verbose};
			mkpath "$dir/$subdir" or die "Cannot create '$dir/$subdir' $!\n";
		}
		print "Copying '$file' to '$dir/$file'\n" if $args{verbose};
		copy("$from/$file", "$dir/$file") or die "Could not copy '$from/$file' $!\n";
		#if ($file =~ /pl$/) {
			chmod 0755, "$dir/$file" or warn "Cannot chmod '$dir/$file' $!\n";
		#}
	}

	if (not -e "$dir/db") {
		mkpath "$dir/db";
		chmod 0777, "$dir/db";
	}
}


1;


