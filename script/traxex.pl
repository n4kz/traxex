#!/usr/bin/env perl
use lib 'lib';
use warnings;
use Getopt::Long;
use Alleria;
use Alleria::Core 'strict';
use open qw{ :std :utf8 };

my %options;
GetOptions(\%options, 'daemon', 'logfile=s');

my $xmpp = do 'xmpp.conf';
my $chat = do 'chat.conf';

my $bot = Alleria->new(
	logfile  => $options{'logfile'}  || 'traxex.log',
	password => $xmpp->{'password'},
	host     => $xmpp->{'host'},
	username => $xmpp->{'username'},
	resource => $xmpp->{'resource'},
	tls      => 1,
);

$bot->load(qw{ message presence iq commands access subscription error muc });
$bot->load(qw{ commands/system commands/roster commands/help });
$bot->load(qw{ iq/version iq/time iq/last });

$bot->rules(do 'access.conf');

require Traxex;

$bot->load('daemon')->daemonize()
	if $options{'daemon'};

$bot->start();

while (my ($room, $nick) = each %$chat) {
	$bot->join($room => { nick => $nick });
}

while ($bot->ok()) {
	# Main loop
} continue {
	$bot->process();
};

$bot->stop();
