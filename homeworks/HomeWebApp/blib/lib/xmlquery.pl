use strict;
use warnings;
use MIME::Base64;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
 
my $content = qq(<?xml version="1.0"?>
 <methodCall>
   <methodName>evaluate</methodName>
   <params>
     <param>
         <value>2+3*(5-7)^2</value>
     </param>
   </params>
 </methodCall>);
my $auth = "Basic " . encode_base64('5b14be416d24ddd21580883f744f391b');


my $response = $ua->post('http://localhost:3000/xml', Authorization => $auth, Content => $content);
 
if ($response->is_success) {
    print $response->decoded_content;  # or whatever
}
else {
    die $response->status_line;
}





