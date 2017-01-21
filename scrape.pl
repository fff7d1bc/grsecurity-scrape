#!/usr/bin/env perl

use warnings;
use strict;
use autodie qw / :all /;
use LWP::UserAgent;
use File::Basename qw/ fileparse /;
use File::Path qw/ rmtree /;

sub einfo {
    printf( "[INFO] >>> %s\n", join( ' ', @_ ) );
}

sub fetch {
    my ( $url, $save_to ) = @_;

    my $ua = LWP::UserAgent->new;

    einfo( "Fetching $url ..." );

    my $response = $ua->get( $url, 'Accept-Encoding' => 'gzip' );

    if ( $response->is_success ) {
        if ( $save_to ) {
            open( my $file, '>', $save_to );

            my $content = $response->decoded_content;

            if ( utf8::is_utf8( $content ) ) {
                binmode( $file,':utf8' );
            } else {
                binmode( $file,':raw' );
            }

            print $file $content;
            close( $file );
            return 1;
        } else {
            return $response->decoded_content;
        }
    } else {
        die "Fetch failed.\n";
    }
}

my $script_dir = ( fileparse( __FILE__ ) )[1];
chdir( $script_dir );

my $latest_patch = fetch( 'https://grsecurity.net/latest_test_patch' );
chomp( $latest_patch );
einfo "Latest patch $latest_patch";

my ( $grsec_major_version, $kernel_version, $grsec_patch_version ) = ( $latest_patch =~ m/^grsecurity-([0-9.]+)-([0-9.]+)-([0-9]+)\.patch$/ );

for my $var ( $grsec_major_version, $kernel_version, $grsec_patch_version ) {
    die "Wrong patch file name?\n" unless defined( $var ) and length $var;
}

if ( -f "test/$kernel_version/$latest_patch" ) {
    einfo "Already downloaded.";
    exit 0;
}

if ( -d 'tmp' ) {
    rmtree( 'tmp' );
}
mkdir( 'tmp' );

fetch( "https://grsecurity.net/test/$latest_patch", "tmp/$latest_patch" );
fetch( "https://grsecurity.net/test/$latest_patch.sig", "tmp/$latest_patch.sig" );
fetch( 'https://grsecurity.net/changelog-test.txt', 'tmp/changelog-test.txt' );

mkdir( "test/$kernel_version" ) if not ( -d "test/$kernel_version" );
rename( "tmp/$latest_patch", "test/$kernel_version/$latest_patch" );
rename( "tmp/$latest_patch.sig", "test/$kernel_version/$latest_patch.sig" );
rename( 'tmp/changelog-test.txt', 'test/changelog-test.txt' );

einfo 'git add ..,';
system( 
    "git", "add",
    "test/$kernel_version/$latest_patch",
    "test/$kernel_version/$latest_patch.sig",
    'test/changelog-test.txt'
);

einfo 'git commit ...';
system(
    "git", "commit", "-m", "Auto commit, $latest_patch added.", 
    "test/$kernel_version/$latest_patch", 
    "test/$kernel_version/$latest_patch.sig", 
    'test/changelog-test.txt'
);

einfo 'git push ...';
system("git", "push");
