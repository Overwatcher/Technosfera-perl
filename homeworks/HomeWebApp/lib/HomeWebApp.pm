package HomeWebApp;

use Template;
use JSON::XS;
use HTTP::Headers;
use Mojo::DOM;
use DDP;
use Encode;
use MIME::Base64;
use DBI qw(:sql_types);
use strict;
use warnings;
use Dancer2;
use Digest::MD5 qw(md5_hex);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Evaluate;
use Local::Rpn;
use Local::Tokenize;
use v5.018;
#use Cache::Memcached::Fast;

our $VERSION = '0.1';

set session => "Simple";

#Memcache will store ("$user->{id}" => {left => integer, time => integer) pairs



#our @xmlusers;

our $error = 0;

our $config = get_config();

our $dbh = get_dbh();

our $secret_word = $config->{secret_word};

#our $memcache = new Cache::Memcached::Fast(
#    {
#	servers => [{address => "$config->{Memcache}"}]
#    });

#$SIG{INT} = sub {
#    my $savedb_sth = $dbh->prepare ( qq(UPDATE user SET time=?, reqleft=? WHERE id=?;) );
#    for (@xmlusers) {
#	my $info = $memcache->get($_);
#	$savedb_sth->execute($info->{time}, $info->{left}, $_);
#    }
#    $memcache->disconnect_all;
#    exit 0;
#};

sub ALREADYEXISTS {1};
sub PASSDIF {2};
our $DEFAULT = 10; #в минуту
sub BADNAME {3};

my $userbynick_sth = $dbh->prepare ( qq(SELECT  * FROM user WHERE nick=?;) );

my $userbytoken_sth = $dbh->prepare ( qq(SELECT id, ratelimit, time, reqleft FROM user WHERE token=?;) );

my $add_sth = $dbh->prepare( qq(INSERT INTO user (nick, password,
name, surname,
fathername, url, ratelimit, time, reqleft) values (?, ?, ?, ?, ? ,?, $DEFAULT, 0, $DEFAULT ); ) );

my $edit_sth = $dbh->prepare( qq(UPDATE user SET
name=?, surname=?,
fathername=?, url=? WHERE id=?; ) );

my $pass_sth = $dbh->prepare ( qq(UPDATE user SET password=? WHERE id=?;) );

my $token_sth = $dbh->prepare ( qq(UPDATE  user SET token=? WHERE id=?;) );

my $delete_sth = $dbh->prepare ( qq(DELETE FROM user WHERE id=?;) );

my $getall_sth = $dbh->prepare( qq(SELECT * FROM user;) );

my $updatexml_sth = $dbh->prepare( qq(UPDATE user SET reqleft=?, time=? WHERE id=?) );

sub add_user {
    my $user = shift;
    $$user{password} = pass_hash($$user{password});
    _decode_hash($user);
    $add_sth->execute($$user{nick}, 
		      $$user{password},
		      $$user{name},
		      $$user{surname},
		      $$user{fathername},
		      $$user{url} );
    
};

sub get_config {
    open (my $fh, "<", "$FindBin::Bin/../config") or die "$!";
    my @strings = <$fh>;
    my $string = join ('', @strings);
    $string =~ s/\s*+//sg;
    $string =~ s/\n//sg;
    return decode_json($string);
};

sub get_dbh {
    my $string;
    my $statements;
    if  (!-e "$FindBin::Bin/../$$config{DBName}") {
	open (my $fh, "<", "$FindBin::Bin/../$$config{DBSchema}") or die "$!";
	my @strings = <$fh>;
	$string = join ('', @strings);
	$string =~ s/\n//sg;
	$statements = decode_json($string);
    }
    my $dbh = DBI->connect("dbi:$$config{DBD}:dbname=$FindBin::Bin/../$$config{DBName}",
			   "","", {RaiseError =>1}) or die $DBI::errstr;
    if (defined $string) {
	for (@$statements) {
	    $dbh->do( qq($_) );
	}
    }
    $$dbh{sqlite_unicode} = 1;
    return $dbh;
}

sub edit_user {
    my ($edited, $nick) = @_;
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fetchrow_hashref;
    my $newpass;
    if ( defined $$edited{password} and $$edited{password} ne '' ) {
	$newpass = pass_hash( $$edited{password} );
	$pass_sth->execute($newpass, $$user{id});
    }
    p $edited;
    _decode_hash($edited);
    $edit_sth->execute($$edited{name},
		       $$edited{surname},
		       $$edited{fathername},
		       $$edited{url},
		       $$user{id});
    
    1;
};

sub delete_user {
    my $nick = shift;
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fetchrow_hashref;
    $delete_sth->execute($$user{id});
    app->destroy_session;
};

sub get_fields {
    my $fields = shift;
    my $hash = {};
    for my $field (@$fields) {
	$$hash{$field} = body_parameters->get($field);
    }
    return $hash;
    
}

sub get_token {
    my $nick = shift;
    my $token = int(rand(10000)) . $nick;
    $token = md5_hex($token);
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fetchrow_hashref;
    $token_sth->execute($token, $$user{id});
    return $token;
};

sub check_reg {
    my $user = shift;
    $$user{nick} = lc $$user{nick};
    p $$user{nick};
    unless ($$user{nick} =~ m/^[a-zA-Z0-9]{4,15}$/) {
	return BADNAME;
    }
    $userbynick_sth->execute($$user{nick});
    my $check = $userbynick_sth->fetchrow_hashref;
    if (defined $$check{id}) {return  ALREADYEXISTS;}
    if ($$user{password} ne $$user{passwordcheck}) {return  PASSDIF;}
    return 0;
};

sub pass_hash {
    my $pass = shift;
    return md5_hex($pass . $secret_word);
}


sub _decode_hash {
    my $hash = shift;
    for (keys %$hash) {
	$$hash{$_} = decode_utf8( $$hash{$_} )
    }
}

sub pass_check {
    my ($readpass, $nick) = @_;
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fethrow_hashref;
    if ($$user{password} eq pass_hash($readpass) ) {
	return 1;
    }
   return 0;
}

get '/' => sub {
    redirect '/web';
};

get '/web' => sub {
    my $user = 0;
    my $insession = 0;
    if (defined session('user')) {$user = session('user'); $insession = 1;}
    template 'main', {user => $user, insession => $insession};
};
get '/web/login' => sub {
    our $buf = $error;
    my ($user, $insession);
    $error = 0;
    if (defined session('user')) {$user = session('user'); $insession = 1;}
    template 'login', {wronglog => $buf, insession => $insession, user => $user};
};
get '/web/reg' => sub {
    our $buf = $error;
    $error = 0;
    my ($user, $insession);
    if (defined session('user')) {$user = session('user'); $insession = 1;}
    template 'reg', {error => $buf, insession => $insession, user => $user};
};
post '/web/reg' => sub {
    my $user = {};
    my @fields = qw(nick password passwordcheck surname name fathername url);
    $user = get_fields(\@fields);
    $error = check_reg($user);
    if ($error) {redirect 'web/reg';}
    add_user($user);
    session user => $$user{nick};
    redirect "web/edit/$$user{nick}";
};
post '/web/login' => sub {
    my $nick = body_parameters->get('nick');
    my $pass = body_parameters->get('password');
    $userbynick_sth->execute($nick);
    my $check = $userbynick_sth->fetchrow_hashref;
    p $check;
    if (!defined $$check{password} or $$check{password} ne pass_hash($pass) ) {
	$error = 1;
	redirect '/web/login';
    }
    else {
	session user => $nick;
	session csrf => int ( rand(10000) );
	redirect 'web';
    }
    
};
get '/web/edit/*' => sub {
    my $body = request->body;
    p $body;
    my ($nick) = splat;
    if (!defined session('user') or $nick ne session('user')) {redirect 'web/login';}
    $userbynick_sth->execute( $nick );
    my $user = $userbynick_sth->fetchrow_hashref;
    template 'edit', {user => $user, insession => 1, csrf => pass_hash(session('csrf'))};
};

post '/web/edit/*' =>sub {

    my $nick = session('user');
    if (!defined $nick) {redirect '/';}

    my $csrf = pass_hash( session('csrf') );
    if (body_parameters->get('csrf') ne $csrf) {return "$csrf Hacker, huh?";}
    
    if (defined body_parameters->get('delete')) {delete_user($nick); redirect '/';}
    my @fields = qw(password  surname name fathername url);
    my $edited = get_fields(\@fields);
    edit_user($edited, $nick);
    redirect "/web/edit/$nick";
};
get '/web/gettoken' => sub {
    my $nick;
    my $gottoken = 0;
    my $token;
    if (defined session('user')) {$nick = session('user');}
    else {redirect '/web/login';}
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fetchrow_hashref;
    if (defined $$user{token}) {$gottoken = 1; $token = $$user{token};}
    template 'gettoken', {gottoken => $gottoken, 
			  token => $token, 
			  user => $nick, 
			  insession => 1,
			  csrf => pass_hash(session('csrf'))};
};
post '/web/gettoken' => sub {
    my $nick;
    if (defined session('user')) {$nick = session('user');}

    my $csrf = pass_hash( session('csrf') );
    if (body_parameters->get('csrf') ne $csrf) {return 'Hacker, huh?';}
    
    get_token($nick);
    redirect 'web/gettoken';
};


#XML PART ==========================================================================================


#STARTS HERE =======================================================================================

sub get_arg {
    my ($dom) = @_;
    my $argument = $dom->at('param');
    $argument = $argument->at('value');
    if (defined $argument->text) {return $argument->text;}
    $argument = $argument->at('string');
    if (!defined $argument) {
	return undef;
    }
    $argument = $argument->text;
    return $argument;
}

sub update_limit {
    my $user = shift;
    p $user;
    my $dif;
    my $retval = 0;
    $dif = time() - $$user{time};
    if ( $dif < 60 and $$user{reqleft} >= 1 ) {
	$$user{reqleft} --;
        $retval =  1;
    }
    if ( $dif >=60 ) {
	$$user{reqleft} = $$user{ratelimit} - 1;
	$$user{time} = time();
        $retval = 1;
    }
    $updatexml_sth->execute($$user{reqleft}, $$user{time}, $$user{id});
    return $retval;
}

sub xml_response_ok {
    my $ref = shift;
    my $nl = "\015\012";
    my $body = qq(<?xml version="1.0"?>$nl<methodResponse>$nl);
    if (ref $ref eq 'ARRAY') {
	$body .= "\t<params>$nl";
	for (@$ref) {
	    $body .= "\t\t<param>$nl\t\t\t<value><string>$_</string></value>$nl\t\t</param>$nl";
	}
	$body .= "\t</params>$nl";
	$body .= "</methodResponse>";
	return $body;
    }
    if (ref $ref eq '') {
	my $body =qq( <?xml version="1.0"?>
 <methodResponse>
   <params>
     <param>
         <value><string>$ref</string></value>
     </param>
  </params>
 </methodResponse>);
	return $body;
    }
}

sub xml_response_fault {
    my $reason = shift;
 return qq(<?xml version="1.0"?>
    <methodResponse>
        <fault>
            <value>$reason</value>
        </fault>
    </methodResponse>);
}


get 'xml' => sub {
    return "For POST XML-RPC query only. Use a POST method with basic auth."
};

my $response;

get 'xml/*' => sub {
    my $token = splat;
    return $response;
};

post 'xml' => sub {
    my $token = request->header('Authorization');
    if ($token =~ m{^\s*Basic\s*([^\s]+)}) {
	$token = decode_base64($1);
    } else {
	return $response = xml_response_fault("Authorization failed");
    }
    $userbytoken_sth->execute($token);
    my $user = $userbytoken_sth->fetchrow_hashref;
    if (!defined $user) {
	return $response = xml_response_fault("Authorization failed");
    }
    if ( !update_limit($user) ) {
	return $response = xml_response_fault("Wait a bit. You have reached your ratelimit");
    }
    my $body = request->body;
    my $dom = Mojo::DOM->new($body);
    my $method = $dom->at('methodCall');
    $method = $method->at('methodName');
    my $methodName = $method->text;
    if (!defined $methodName) {
	$response = xml_response_fault;
    }
    
    my $argument = get_arg($dom);
    if ($methodName eq 'evaluate') {
	$response = xml_response_ok( evaluate($argument) );
	return $response;
	
    }
    if ($methodName eq 'rpn') {
	$response = xml_response_ok( rpn($argument) );
	return $response;
    }
    if ($methodName eq 'tokenize') {
	$response = xml_response_ok( tokenize($argument) );
        return $response;
    }
    $response = xml_response_fault;
    return $response;
};


#ADMINISTRATION PART ==========================================================================================

#STARTS HERE ==================================================================================================

get 'administration' => sub {
    if (session('user') ne 'admin') { redirect '/web'; }
    $getall_sth->execute();
    my $users = $getall_sth->fetchall_arrayref({});;
    template 'administration', {admin => 'admin', users => $users, csrf => pass_hash(session('csrf'))};
};

post 'administration' => sub {
    
    if (session('user') ne 'admin') { redirect '/web'; }
    my $csrf = pass_hash( session('csrf') );
    if (body_parameters->get('csrf') ne $csrf) {return 'Hacker, huh?';}
    warn (body_parameters->get('csrf'));
    
    my $bp = body_parameters;
    my $ratelimit_sth = $dbh->prepare( qq(UPDATE user SET ratelimit=? WHERE id=?;) );
    my $id;
    for my $key ($bp->keys) {
	if ($key  ne 'submit') {
	    $key =~ /ratelimit\.(\d*)/;
	    $id = $1;
	    my $rl = $bp->get($key);
	    $ratelimit_sth->execute($rl, $id);
	}
    }
    redirect 'administration';
};

get 'administration/view=*' => sub {
    if (session('user') ne 'admin') { redirect '/web'; }
    my ($nick) = splat;
    $userbynick_sth->execute($nick);
    my $user = $userbynick_sth->fetchrow_hashref;
    my @fields = qw(id name surname fathername url);
    template 'view', {admin => 'admin', user => $user, fields => \@fields};
};

post 'administration/delete=*' => sub {
    if (session('user') ne 'admin') { redirect '/web'; }

    my $csrf = pass_hash( session('csrf') );
    if (body_parameters->get('csrf') ne $csrf) {return 'Hacker, huh?';}
    
    my ($id) = splat;
    my $sth = $dbh->prepare(qq(SELECT nick FROM user WHERE id=?));
    $sth->execute($id);
    my $user = $sth->fetchrow_hashref;
    if ( $user->{nick}  eq 'admin' ) {redirect 'administration';}
    $delete_sth->execute($id);
    redirect 'administration';
};
dance;
