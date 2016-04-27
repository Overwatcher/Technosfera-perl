#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Habr;
use DDP;
use Getopt::Long qw(GetOptionsFromString);
my %options;


while (<>) {
	for my $key (keys %options) {
		delete $options{$key};
	}
	$options{format} = 'json';
	if ( $_ =~ m/^\s*user\s*(.*)/) {
		GetOptionsFromString($1, \%options, 'name=s', 'post=i', 'format=s', 'refresh');
		my $user;
		if (defined $options{name}) {
			if ($options{refresh}) { $user = getuser_habr($options{name}); }
			else {$user = get_user($options{name});}
		}
		if (defined $options{post}) {
			if ($options{refresh}) {
				my $post = getpost_habr($options{post});
				$user = getuser_habr($$post{author});
			}
			else {
				my $post = get_post($options{post});
				$user = get_user($$post{author});
			}
		}
		if (!defined $user) {die 'No way to determine a user';}
		myprint($user, $options{format});
		next;
	}
	if ($_ =~ m/^\s*post\s*(.*)/) {
		print $1;
		GetOptionsFromString($1, \%options, 'id=i', 'format=s', 'refresh');
		my $post;
		if ( $options{refresh} ) { $post = getpost_habr($options{id}); }
		else {$post = get_post($options{id});}
		myprint($post, $options{format});
		next;
	}
	if ($_ =~ m/^\s*commenters\s*(.*)/) {
		GetOptionsFromString($1, \%options, 'post=i', 'format=s', 'refresh');
		my $post;
		if ( $options{refresh} ) { $post = getpost_habr($options{post}); }
		else {$post = get_post($options{post});}
		myprint( get_commentors($post), $options{format} );
		next;
	}
	if ($_ =~ m/^\s*self_commentors\s*(.*)/) {
		GetOptionsFromString($1, \%options, 'format=s', 'refresh');
		myprint(self_commentors(), $options{format});
		next;
	}
	if ($_ =~ m/^\s*desert_posts\s*(.*)/) {
		GetOptionsFromString($1, \%options, 'format=s', 'n=i', 'refresh');
		myprint( desert_posts($options{n}), $options{format} );
		next;
	}
}
