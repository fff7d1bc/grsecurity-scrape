#!/usr/bin/perl

use warnings;
use strict;
use XML::Simple;
use LWP::Simple 'get', 'getstore';
use File::Basename 'dirname', 'basename';
use Cwd 'abs_path';

my $script_dir = abs_path(dirname(__FILE__));

my $feed_raw = get("https://grsecurity.net/testing_rss.php");

my $feed = XMLin($feed_raw, ForceArray => ['item']);
my $filename;
my $link;
my $new_patches;

for(@{$feed->{channel}->{item}}) {
	$link = $_->{link};
	$filename = basename($link);
	if ( ! -e $script_dir . "/test/". $filename ) {
		$new_patches++;
		print("Downloading ", $filename, " ...\n");
		getstore($link . ".sig", $script_dir . "/test/" . $filename . ".sig");
		getstore($link, $script_dir . "/test/" . $filename);
	}
}
if ($new_patches) {
	print("Downloading changelog-test.txt ...\n");
	getstore("https://grsecurity.net/changelog-test.txt", $script_dir . "/test/changelog-test.txt");
	
	system("git", "add", $script_dir . "/test/" . $filename, $script_dir . "/test/changelog-test.txt", $script_dir . "/test/" . $filename . ".sig");
	system("git", "commit", "-a", "-m", "Auto commit, " . $new_patches . " new patch{es}.");
	system("git", "push");
}

