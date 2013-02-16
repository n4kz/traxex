package Traxex;
use Alleria::Core 'strict';
use Vermishel::Client;
use JSON;
use Digest::MD5 'md5_hex';
use Text::Markdown 'markdown';
#use Redis;

my $config    = do 'traxex.conf';
my $vermishel = Vermishel::Client->new(%{ $config->{'vermishel'} });
my $types     = {};

#my $redis     = Redis->new(ecoding => undef);
#$redis->select($config->{'redis'}{'db'} //= 0);

$vermishel->authenticate();

our ($author, $self);

sub message ($) {
	$self->message({
		to   => $author,
		body => $_[0],
	});
} # message

{
	# Create stream on demand
	my ($response) = $vermishel->createStream({ stream => $config->{'stream'} });

	if ($response->{'error'}) {
		given ($response->{'error'}{'message'}) {
			break when /exists/;

			die $response->{'error'}{'message'};
		}
	}

	# Get identifiers for type messages
	($response) = $vermishel->getTagStream({
		stream => $config->{'stream'},
		tag    => ':type',
	});

	die $response->{'error'}{'message'}
		if $response->{'error'};

	$types->{$_->{'body'}} = $_->{'id'}
		foreach @{ $response->{'result'}{'stream'} };

	foreach (@{ $config->{'types'} }) {
		next if $types->{$_};

		($response) = $vermishel->createMessage({
			stream => $config->{'stream'},
			body   => $_,
			meta   => to_json({ type => 'type' }),
		});

		die $response->{'error'}{'message'}
			if $response->{'error'};

		$types->{$_} = $response->{'result'}{'id'};
	}
}

my $typehelp = join ' | ', @{ $config->{'types'} };

Alleria->load('commands')->commands({
	issue => {
		arguments   => '<text...>',
		description => 'Create new issue',
	},

	comment => {
		arguments   => '<id> <text...>',
		description => 'Reply to issue',
	},

	mark => {
		arguments   => join($typehelp, '<id> <', '>'),
		description => 'Mark issue as open or closed',
	},

	show => {
		arguments   => join($typehelp, '[<id> | <', '> | comments <id>]'),
		description => 'Show all open issues, issue/comment by id or issues by type',
	},

	#auth => 'Get authentication url',
});

Alleria->focus('message::command' => sub {
	local our ($self, $author);
	my ($event, $args, $message);

	($self, $event, $args) = @_;

	$message = $args->[0];
	$author  = $message->{'from'};
	$args    = $message->{'arguments'};

	given ($message->{'command'}) {
		my $issue;

		when ('comment') {
			($issue, $args) = split m{ +}, $args, 2;

			return message 'Issue id required'
				unless $issue;

			# Get parent issue
			my ($response) = $vermishel->getMessage({ message => $issue });

			# Check for errors
			return message 'Got error for your request '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Check parent type
			return message 'Only replies to issues are allowed'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			# Okay, fall through
			$_ = 'issue', continue;
		}

		when ('issue') {
			return message 'Issue text required'
				unless $args;

			# Post message
			my ($response) = $vermishel->createMessage({
				stream => $config->{'stream'},
				body   => markdown($args),
				meta   => to_json({
					type   => $issue? 'comment' : 'issue',
					author => {
						jid  => (split '/', $author)[0],
						name => (split '@', $author)[0],
					},
				}),

				($issue? (replyto => $issue) : ()),
			});

			# Check for errors
			return message 'Got error for your request '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Get id
			my $id = $response->{'result'}{'id'};

			# Mark as open
			$vermishel->setLink({
				messageA => $id,
				messageB => $types->{'open'},
			}) unless $issue;

			# Send message to author
			message join ' created with id #', $issue? 'Comment' : 'Issue', $id;

			# Notify other users
			if ($self->can('roster')) {
				foreach (grep { $_ ne $author } $self->roster('online')) {
					$self->message({
						to   => $_,
						body => $issue?
							"New comment with #$id was added to issue #$issue by $author":
							"New issue #$id was opened by $author",
					});
				}
			}
		}

		when ('mark') {
			my ($issue, $type) = split m{ +}, $args, 2;

			# Check arguments
			return message 'Wrong arguments'
				unless $types->{$type};

			# Get target issue
			my ($response) = $vermishel->getMessage({ message => $issue });

			return message 'Got error for your request '. $response->{'error'}{'message'}
				if $response->{'error'};

			return message 'Wrong issue id'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			# Unset all possible types
			foreach (keys %$types) {
				# TODO: Check reponse
				$vermishel->unsetLink({
					messageA => $issue,
					messageB => $types->{$_},
				});
			}

			# Set desired type
			($response) = $vermishel->setLink({
				messageA => $issue,
				messageB => $types->{$type},
			});

			return message 'Got error for your request '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Create comment
			($response) = $vermishel->createMessage({
				stream  => $config->{'stream'},
				body    => "Marked as $type",
				replyto => $issue,
				meta    => to_json({
					type => 'comment',
					author => {
						jid  => (split '/', $author)[0],
						name => (split '@', $author)[0],
					},
				})
			});

			return message 'Got error for your request '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Send message to author
			message "Marked #$issue as $type";

			# Notify other users
			if ($self->can('roster')) {
				foreach (grep { $_ ne $author } $self->roster('online')) {
					$self->message({
						to   => $_,
						body => "Issue #$issue was marked as $type by $author",
					});
				}
			}
		}

		when ('show') {
			my (@results, $response, $issue);

			$args = 'open'
				unless $args;

			given ($args) {
				when (m{^\d+$}) {
					($response) = $vermishel->getMessage({ message => $args });

					return message 'Got error for your request '. $response->{'error'}{'message'}
						if $response->{'error'};

					@results = $response->{'result'};
				}

				$issue = $1 and continue
					when m{^comments +(.*)};

				default {
					return message 'Unsupported type '. $args
						unless $issue or exists $types->{$args};

					do {
						($response) = $vermishel->getLinkStream({ message => $issue || $types->{$args} });

						return message 'Got error for your request '. $response->{'error'}{'message'}
							if $response->{'error'};

						last unless push @results, @{ $response->{'result'}{'stream'} };

					# TODO: move to config
					} while not @results % 50;
				}
			}

			message join "\n", '', map {
				sprintf '#%i (%i) %s', grep {
					s{</?\w+.*?>} {}ig or 1
				} @{ $_ }{qw{ id linked body }}
			} grep {
				not $issue or $_->{'meta'}{'type'} eq 'comment'
			} reverse @results;
		}

		#when ('auth') {
		#	my $secret = md5_hex join ':', $$, $config->{'secret'}, $message->{'from'};
		#	my $url    = join '/auth/', $config->{'host'}, $secret; 

		#	# Save token to redis
		#	$redis->setex($config->{'redis'}{'keys'}{'auth'}. $secret => 3600 => $message->{'from'}, sub {});

		#	# Send auth url back
		#	message $url;
		#}
	}
});

1;
