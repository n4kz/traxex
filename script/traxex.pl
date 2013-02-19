#!/usr/bin/perl -Ilib
use Getopt::Long;
use Alleria;
use Alleria::Core 'strict';

my %options;
GetOptions(\%options, 'daemon', 'logfile=s', 'password=s');

my $bot = Alleria->new(
	logfile  => $options{'logfile'}  || 'traxex.log',
	password => $options{'password'} || do 'password.conf',
	host     => 'n4kz.com',
	username => 'traxex',
	resource => 'vermishel',
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

$bot->join('vermishel@conference.n4kz.com' => { nick => 'traxex' });

while ($bot->ok()) {
	# Main loop
} continue {
	$bot->process();
};

$bot->stop();