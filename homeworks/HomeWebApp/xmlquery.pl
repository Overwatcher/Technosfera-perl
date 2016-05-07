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
         <value>1234+324^2/234*(2^3+3)</value>
     </param>
   </params>
 </methodCall>);
my $auth = "Basic " . encode_base64('e82053f1727c93853607f234e667e89e');


my $response = $ua->post('http://localhost:5000/xml', Authorization => $auth, Content => $content);
 
if ($response->is_success) {
    print $response->decoded_content;  # or whatever
}
else {
    die $response->status_line;
}





