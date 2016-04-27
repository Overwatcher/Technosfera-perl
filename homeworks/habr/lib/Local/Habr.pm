package Local::Habr;

use strict;
use warnings;
use LWP::UserAgent;
use DBI;
use Exporter 'import';
use JSON::XS;
use XML::Hash::LX;
use Mojo::DOM;
use Encode;
use utf8;
use DDP;
use feature 'postderef';
our @EXPORT = qw(get_user 
	get_post 
	getbypost 
	get_commentors 
	getuser_habr  
	getpost_habr 
	self_commentors
	desert_posts
	myprint);

our $dbh = DBI->connect("dbi:SQLite:dbname=dbfile",
    "","") or die $DBI::errstr;

our $habr = 'https://habrahabr.ru';

sub getuser_habr {
	my $nick = shift;
	my $user;
	my $ua = LWP::UserAgent->new(
		timeout => 10);
	$ua->env_proxy;
	my $response = $ua->get("$habr/users/$nick/");
	if ($response->is_success()) {
		$user = parser_user($response->decoded_content);
	} else {
		print "\nNo such user $nick or other error\n";
	}
	for (keys %$user) {
		$$user{$_} =~ s/,/\./;
		$$user{$_} =~ s/–/\-/;
	}
	$$user{nick} = $nick;
	add_user($user);
	return $user;
};

sub getpost_habr {
	my $id = shift;
	my $post;
	my $ua = LWP::UserAgent->new(
		timeout => 10);
	$ua->env_proxy;
	my $response = $ua->get("$habr/post/$id/");
	if ($response->is_success()) {
		$post = parser_post($response->decoded_content);
	} else {
		print "\nNo such post $id or other error\n";
	}
	$post->{id} = $id;
	add_post($post);
	return $post;
};

sub parser_user {
	my $content = shift;
	my $dom = Mojo::DOM->new($content);
	my $rating = $dom->at('div[class="statistic__value statistic__value_magenta"]');
	if (!defined $rating) {$rating = -1;}
	else {
		$rating = $rating->text;
	}
	my $karma = $dom->at('div[class="voting-wjt__counter-score js-karma_num"]');
	if (!defined $karma) {$karma = -1;}
	else {
		$karma = $karma->text;
	}
	return {rating => $rating, karma => $karma};
};

sub parser_post {
	my $content = shift;
	my $dom = Mojo::DOM->new($content);
	my %commenters;
	my $title = $dom->at('span[class="post_title"]')->text;
	my $author = $dom->at('div[class="profile-header__summary author-info author-info_profile "]');
	$author = $author->at('a["href"]');
	if ($author =~ m/users\/([^\/]*+)\//) {
		$author = $1;
	}
	my $collection = $dom->find('span[class="comment-item__user-info"]');
	for (0..scalar(@$collection) - 1) {
		my $nick = $collection->[$_]->attr("data-user-login");
		$commenters{$nick} = 1;
	}
	my $views = $dom -> at('div[class="views-count_post"]')->text;
	$views =~ s/,/\./;
	$views =~ s/k/e\+3/;
	my $rating = $dom->at('span[class="voting-wjt__counter-score js-score"]')->text;
	my $stars = $dom->at('span[class="favorite-wjt__counter js-favs_count"]')->text;
	my @commenters = keys %commenters;
	my $comm_number = $dom->at('span[id="comments_count"]')->text;
	return {
		title => $title, 
		author => $author, 
		commenters => \@commenters, 
		views =>0 + $views, 
		rating =>0 + $rating, 
		stars =>0 + $stars,
		comm_number => 0 + $comm_number};
};

sub get_user {
	my $nick = shift;
	my $sth = $dbh->prepare( qq(select * from user where nick="$nick";) );
	my $user = $dbh->selectrow_hashref($sth);
	if (!defined $user) {
		$user = getuser_habr($nick);
		add_user($user);
	}
	return $user;
};

sub get_post {
	my $id = shift;
	my $sth = $dbh->prepare( qq(select * from post where id="$id";) );
	my $post = $dbh->selectrow_hashref($sth);
	if (!defined $post) {
		$post = getpost_habr($id);
		for ($post->{commenters}->@*) {
			my $user = $dbh->selectrow_hashref( qq(select * from user where nick="$_";) );
			if (!defined $user) {
				add_user(getuser_habr($_));
			}
		}
		add_post($post);
	}
	return $post;
}

sub add_user {
	my $user = shift;
	my $check = $dbh->selectrow_hashref( qq(select * from user where nick="$user->{nick}";) );
	if (defined $check) {$dbh->do( qq(delete from user where nick="$user->{nick}";) );}
	$dbh->do( qq(insert into user (nick, karma, rating) values ("$user->{nick}", "$user->{karma}", "$user->{rating}"); ) );
};

sub add_post {
	my $post_orig = shift;
	my %post = %$post_orig;
	my $post = \%post;
	my $check = $dbh->selectrow_hashref( qq(select * from post where id=$$post{id};) );
	if (defined $check) {$dbh->do( qq(delete from post where id="$post->{id}";) );}
	my @commenters;
	for ($post->{commenters}->@*) {
		push(@commenters, $_);
		
	}
	my $commenters = encode_json(\@commenters);
	$dbh->do( qq(insert into post (id, author, title, rating, stars, views, commenters, comm_number) values (
		$post->{id},
		"$post->{author}",
		"$post->{title}",
		$post->{rating},
		$post->{stars},
		$post->{views},
		'$commenters',
		$post->{comm_number}); ) );
};
sub self_commentors {
	my $select = $dbh->selectall_hashref( qq(select id, author, commenters from post;), 'id' );
	my @result;
	for (keys %$select) {
		my $commenters = $select->{$_}->{commenters};
		my $author = $select->{$_}->{author};
		if ($commenters =~ m/$author/) {
			$author = get_user($author);
			push(@result, $author);
		}
	}
	return \@result;
};

sub get_commentors {
	my $post = shift;
	my @commenters;
	my $aref = decode_json($post->{commenters});
	for my $user (@$aref) {
		$user = get_user($user);
		push (@commenters, $user);
	}
	return \@commenters;
};

sub desert_posts {
	my $n = shift;
	my $select = $dbh->selectall_arrayref( qq(select * from post where comm_number<$n), { Slice => {} } );
	return $select;
};

sub myprint {
	my ($someref, $format) = @_;
	if (ref($someref) eq 'HASH') {
		_printhash($someref, $format);
	}
	else {
		for my $hash (@$someref) {
			_printhash($hash, $format);
		}
	}
};

sub _printhash {
	my ($hash, $format) = @_;
	my %print = %$hash;
	my $xmlprint;
	if (defined $print{id}) {
		delete $print{commenters};
	}
	if ($format eq 'json') {
		my $json = JSON::XS->new;
		my $string = $json->encode(\%print);
		print "\n$string\n";
		return;
	}
	if ($format eq 'xml') {
		if (defined $print{id}) {
			$xmlprint->{post} = \%print;
		}
		else {
			$xmlprint->{user} = \%print;
		}
		my $string = hash2xml($xmlprint);
		print "\n$string\n";
		return;
	}
	warn "Wrong format";
};
1;
