package Local::Habr;

use strict;
use warnings;
use LWP::UserAgent;
use DBI;
use Exporter 'import';
use JSON::XS;
use XML::Hash::LX;
use Mojo::DOM;
use utf8;
use DDP;
use Getopt::Long;
use FindBin '$Bin';
FindBin::again();
use feature 'postderef';
no warnings 'experimental';	


our @EXPORT = qw(
	execution
	get_user 
	get_post 
	getbypost 
	get_commentors 
	getuser_habr  
	getpost_habr 
	self_commentors
	desert_posts
	myprint);
our $config = get_config();

our $dbh = get_dbh();

our $habr = 'https://habrahabr.ru';

sub get_config {
	open (my $fh, "<", "$Bin/../config") or die "$!";
	my @strings = <$fh>;
	my $string = join ('', @strings);
	$string =~ s/\s*+//sg;
	$string =~ s/\n//sg;
	return decode_json($string);
};

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
	if (!defined $author) {
		$author = $dom->at('div[class=" profile-header__summary author-info author-info_profile"]');
	}
	$author = $author->at('a["href"]');
	if ($author =~ m/users\/([^\/]*+)\//) {
		$author = $1;
	}
	elsif ($author =~ m/company\/([^\/]*+)\//) {
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
	my $comments_count = $dom->at('span[id="comments_count"]')->text;
	return {
		title => $title, 
		author => $author, 
		commenters => \@commenters, 
		views =>0 + $views, 
		rating =>0 + $rating, 
		stars =>0 + $stars,
		comments_count => 0 + $comments_count};
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
		push ($post->{commenters}->@*, $post->{author});
		for ($post->{commenters}->@*) {
			add_user(getuser_habr($_));
		}
		pop $post->{commenters}->@*;
		add_post($post);
	}
	return $post;
}

sub add_user {
	my $user = shift;
	$dbh->do( qq(insert or replace into user (nick, karma, rating) values ("$user->{nick}", "$user->{karma}", "$user->{rating}"); ) );
};

sub add_post {
	my $post = shift;
	$dbh->do( qq(insert or replace into post (id, author, title, rating, stars, views, comments_count) values (
		$post->{id},
		"$post->{author}",
		"$post->{title}",
		$post->{rating},
		$post->{stars},
		$post->{views},
		$post->{comments_count}); ) );
	for ($post->{commenters}->@*) {
		$dbh->do( qq(insert into commenters (user, postid) values ('$_', '$post->{id}');) );
	}
};
sub self_commentors {
	  my $self_commentors = $dbh->selectall_arrayref( q(select  distinct user.nick as nick, user.karma as karma, user.rating as rating
	  		from user JOIN post JOIN commenters
	  		ON (user.nick=post.author and post.id=commenters.postid and post.author=commenters.user);
			), 
	  		{Slice => {} }
	  	);
	  	return $self_commentors;
};

sub get_commentors {
	my $id = shift;
	my $commenters = $dbh->selectall_arrayref( qq( select distinct user.nick as nick, user.karma as karma, user.rating as rating
			from user JOIN post JOIN commenters
			ON (post.id=commenters.postid and commenters.user=user.nick and post.id=$id);
			), 
			{Slice => {} }
		);
		return $commenters;
};

sub desert_posts {
	my $n = shift;
	my $select = $dbh->selectall_arrayref( qq(select * from post where comments_count<$n), { Slice => {} } );
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

sub get_dbh {
	my $string;
	my $statements;
	if  (!-e "$config->{DBName}") {
		open (my $fh, "<", "$Bin/../$config->{DBSchema}") or die "$!";
		my @strings = <$fh>;
		$string = join ('', @strings);
		$string =~ s/\n//sg;
		$statements = decode_json($string);
	}
	my $dbh = DBI->connect("dbi:$config->{DBD}:dbname=$Bin/../$config->{DBName}",
    		"","") or die $DBI::errstr;
	if (defined $string) {
		for (@$statements) {
			$dbh->do( qq($_) );
		}
	}
	return $dbh;
}

sub execution {
	my $arg = shift;
	my %options;
	$options{format} = 'json';
	if ($arg eq 'user') {
		GetOptions(\%options, 'name=s', 'post=i', 'format=s', 'refresh');
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
		return;
	}
	if ($arg eq 'post') {
		GetOptions(\%options, 'id=i', 'format=s', 'refresh');
		my $post;
		if ( $options{refresh} ) { $post = getpost_habr($options{id}); }
		else {$post = get_post($options{id});}
		myprint($post, $options{format});
		return;
	}
	if ($arg eq 'commenters') {
		GetOptions(\%options, 'post=i', 'format=s', 'refresh');
		my $post;
		if ( $options{refresh} ) { $post = getpost_habr($options{post}); }
		else {$post = get_post($options{post});}
		myprint( get_commentors($post->{id}), $options{format} );
		return;
	}
	if ($arg eq 'self_commentors') {
		GetOptions(\%options, 'format=s', 'refresh');
		myprint(self_commentors(), $options{format});
		return;
	}
	if ($arg eq 'desert_posts') {
		GetOptions(\%options, 'format=s', 'n=i', 'refresh');
		myprint( desert_posts($options{n}), $options{format} );
		return;
	}
	die "Wrong arguments";
};
1;
