package Traxex;
use Alleria::Core 'strict';
use Vermishel::Client;
use JSON;
use Digest::MD5 'md5_hex';
use Text::Markdown 'markdown';
use Redis;

my $config    = do 'traxex.conf';
my $vermishel = Vermishel::Client->new(%{ $config->{'vermishel'} });
my $types     = {};
my $defaults  = {};

my $redis     = Redis->new(ecoding => undef);
$redis->select($config->{'redis'}{'db'} //= 0);

$vermishel->authenticate();

our ($author, $self);

# Send message to user
sub message ($) {
	$self->message({
		to   => $author,
		body => $_[0],
	});
} # message

# Create new issue type for project
sub type ($$) {
	my ($name, $type) = @_;

	return 'Type exists already'
		if $types->{$name}{$type};

	return 'Choose another type name'
		if $type !~ m{^\w+$};

	my ($response) = $vermishel->createMessage({
		stream => $name,
		body   => $type,
		meta   => to_json({
			type => 'type',
			tags => ['type'],
		}),
	});

	return 'Got error for your request: '. $response->{'error'}{'message'}
		if $response->{'error'};

	$types->{$name}{$type} = $response->{'result'}{'id'};

	return undef;
} # type

# Update (set) default type
sub deftype ($;$) {
	my ($name, $type) = @_;
	my $response;

	if ($type) {
		return 'Only existing types allowed'
			unless $types->{$name}{$type};

		return undef
			if $type eq ($defaults->{$name} || '');

		($response) = $vermishel->createMessage({
			stream => $name,
			body   => $type,
			meta   => to_json({
				type => 'type',
				tags => ['default'],
			}),
		});
	} else {
		($response) = $vermishel->getTagStream({
			stream => $name,
			tag    => '.default',
		});
	}

	return 'Got error for your request: '. $response->{'error'}{'message'}
		if $response->{'error'};

	unless ($type) {
		my $message = $response->{'result'}{'stream'}[0];

		return 'Default type was not set'
			unless $message;

		$defaults->{$name} = $message->{'body'};
	} else {
		$defaults->{$name} = $type;
	}

	return undef;
} # deftype

# Reload existing types for project
sub types ($) {
	my ($name) = @_;

	# Get identifiers for type messages
	my ($response) = $vermishel->getTagStream({
		stream => $name,
		tag    => '.type',
	});

	return 'Got error for your request: '. $response->{'error'}{'message'}
		if $response->{'error'};

	$types->{$name} = {};

	$types->{$name}{$_->{'body'}} = $_->{'id'}
		foreach @{ $response->{'result'}{'stream'} };

	return 'Project not exists or is not configured'
		unless keys %{ $types->{$name} };

	return deftype $name;
} # types

Alleria->load('commands')->commands({
	issue => {
		arguments   => '<project> <text...>',
		description => 'Create new issue in project',
	},

	comment => {
		arguments   => '<id> <text...>',
		description => 'Reply to issue',
	},

	mark => {
		arguments   => '<id> <type>',
		description => 'Mark issue as open or closed',
	},

	show => {
		arguments   => '[<id> | <project> <type> | comments <id>]',
		description => 'Show all open issues, issue/comment by id or issues by type',
	},

	projects => 'Show available projects',

	project => {
		arguments   => '<name> [<command>] [arguments]',
		description => 'Manage project',
	},

	auth => 'Get authentication url',
});

Alleria->focus('message::command' => sub {
	local our ($self, $author);
	my ($event, $args, $message);

	($self, $event, $args) = @_;

	$message = $args->[0];
	$author  = $message->{'from'};
	$args    = $message->{'arguments'};

	given ($message->{'command'}) {
		my ($issue, $project);

		# Create comment
		when ('comment') {
			($issue, $args) = split m{ +}, $args, 2;

			return message 'Issue id required'
				unless $issue;

			# Get parent issue
			my ($response) = $vermishel->getMessage({ message => $issue });

			# Check for errors
			return message 'Got error for your request: '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Check parent type
			return message 'Only replies to issues are allowed'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			# Okay, fall through
			$_ = 'issue', continue;
		}

		# Create issue
		when ('issue') {
			unless ($issue) {
				my $error;
				($project, $args) = split m{ +}, $args, 2;

				return message 'Project name required'
					unless $project;

				return message 'Issue text required'
					unless $args;

				$error = types $project
					unless $types->{$project};

				return message $error
					if $error;
			} else {
				return message 'Comment text required'
					unless $args;
			}

			# Post message
			my ($response) = $vermishel->createMessage({
				stream => $project,
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
			return message 'Got error for your request: '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Get id
			my $id = $response->{'result'}{'id'};

			# Mark as open
			# TODO: use default type
			$vermishel->setLink({
				messageA => $id,
				messageB => $types->{$project}{ $defaults->{$project} },
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

		# Change issue status
		when ('mark') {
			my ($issue, $type) = split m{ +}, $args, 2;
			my $error;

			# Get target issue
			my ($response) = $vermishel->getMessage({ message => $issue });

			return message 'Got error for your request: '. $response->{'error'}{'message'}
				if $response->{'error'};

			return message 'Wrong issue id'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			# Load types
			$error = types $project
				unless $types->{$project};

			return message $error
				if $error;

			# Check target type
			return message 'Wrong arguments'
				unless $types->{$project}{$type};

			# Unset all possible types
			foreach (values %{ $types->{$project} }) {
				# TODO: Check reponse
				$vermishel->unsetLink({
					messageA => $issue,
					messageB => $_,
				});
			}

			# Set desired type
			($response) = $vermishel->setLink({
				messageA => $issue,
				messageB => $types->{$project}{$type},
			});

			return message 'Got error for your request: '. $response->{'error'}{'message'}
				if $response->{'error'};

			# Create comment
			($response) = $vermishel->createMessage({
				stream  => $project,
				body    => "Marked as $type",
				replyto => $issue,
				meta    => to_json({
					type   => 'comment',
					author => {
						jid  => (split '/', $author)[0],
						name => (split '@', $author)[0],
					},
				})
			});

			return message 'Got error for your request: '. $response->{'error'}{'message'}
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

		# Show issue or comment
		when ('show') {
			my (@results, $response, $issue);

			given ($args) {
				when (m{^\d+$}) {
					($response) = $vermishel->getMessage({ message => $args });

					return message 'Got error for your request: '. $response->{'error'}{'message'}
						if $response->{'error'};

					@results = $response->{'result'};
				}

				$issue = $1 and continue
					when m{^comments +(.*)};

				default {
					my ($project, $type, $error);

					unless ($issue) {
						($project, $type) = split m{ +}, $_, 2;

						return message 'Project name or issue id required'
							unless $project;

						return message $error
							if not $types->{$project} and $error = types $project;

						$type ||= $defaults->{$project};

						return message 'Type was not found in project'
							unless $types->{$project}{$type};
					}

					# TODO: refactor
					{
						do {
							($response) = $vermishel->getLinkStream({ message => $issue || $types->{$project}{$type} });

							return message 'Got error for your request: '. $response->{'error'}{'message'}
								if $response->{'error'};

							last unless push @results, @{ $response->{'result'}{'stream'} };

						# TODO: move to config
						} while not @results % 50;
					}
				}
			}

			message join $/, map {
				sprintf '#%i (%i) %s', @{ $_ }{qw{ id linked body }}
			} grep {
				not $issue or $_->{'meta'}{'type'} eq 'comment'
			} reverse @results;
		}

		# List all projects
		# TODO: list projects for another user
		when ('projects') {
			my (@subscriptions) = $redis->smembers($config->{'redis'}{'keys'}{'user'}{'subscriptions'}. $message->{'from'}); 

			message join $/, @subscriptions;
		}

		# Manage project
		when ('project') {
			my ($name, $command, $args) = split m{ +}, $args, 3;

			return message 'Project name required'
				unless $name;

			given ($command) {

				# Reload and list all types
				when ('types') {
					my $error = types $name;

					return message $error
						if $error;

					message join $/, keys %{ $types->{$name} };
				}

				# Create new type
				when ('type') {
					return message 'Type name required'
						unless $args;

					my $error = type $name, $args;

					return message $error
						if $error;

					message 'New type created';
				}

				# Get/set default type
				when ('default') {
					my $error;

					# Set default type if requested
					$error = deftype $name, $args
						if $args;

					# Reload types on success
					$error ||= types $name;

					return message $error
						if $error;

					return message $defaults->{$name}
						unless $args;

					message 'Default type set';
				}

				default {
					# Try to create new project
					my ($response) = $vermishel->createStream({ stream => $name });

					return message $response->{'error'}{'message'}
						if $response->{'error'};

					message 'Project was created';
				}
			}
		}

		# Authentication
		when ('auth') {
			my $secret = md5_hex join ':', $$, $config->{'secret'}, $message->{'from'}, time, rand;
			my $url    = join '/auth?token=', $config->{'host'}, $secret;

			# Save token to redis
			$redis->setex($config->{'redis'}{'keys'}{'auth'}. $secret, 3600, $message->{'from'}, sub {});

			# Send auth url back
			message $url;
		}
	}
});

1;
