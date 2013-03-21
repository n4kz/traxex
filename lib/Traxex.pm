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

sub _error ($) { "API error: $_[0]" }
sub error  ($) { message &_error }

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
		meta   => to_json({ type => 'type' }),
	});

	return _error $response->{'error'}{'message'}
		if $response->{'error'};

	$types->{$name}{$type} = $response->{'result'}{'id'};

	return undef;
} # type

# Reload existing types for project
sub types ($) {
	my ($name) = @_;

	# Get identifiers for type messages
	my ($response) = $vermishel->getTagStream({
		stream => $name,
		tag    => ':type',
	});

	return _error $response->{'error'}{'message'}
		if $response->{'error'};

	$types->{$name} = {};

	$types->{$name}{$_->{'body'}} = $_->{'id'}
		foreach @{ $response->{'result'}{'stream'} };

	return 'Project not exists or is not configured'
		unless keys %{ $types->{$name} };

	$defaults->{$name} = (sort {
		$types->{$name}{$a} <=> $types->{$name}{$b}
	} keys %{ $types->{$name} })[0];

	return undef;
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
		description => 'Show all issues with default type, issue/comment by id or issues by type',
	},

	projects => 'List available to user projects',

	list => 'List all projects',

	project => {
		arguments   => '<name> [<command>] [arguments]',
		description => <<''
Manage project
Commands:
- create
- grant  <jid>
- revoke <jid>
- type <type>
- types

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
			return error $response->{'error'}{'message'}
				if $response->{'error'};

			# Check parent type
			return message 'Only replies to issues are allowed'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			$project = $response->{'result'}{'stream'};

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
			return error $response->{'error'}{'message'}
				if $response->{'error'};

			# Get id
			my $id = $response->{'result'}{'id'};

			# Mark as open
			$vermishel->setLink({
				messageA => $id,
				messageB => $types->{$project}{ $defaults->{$project} },
			}) unless $issue;

			# Send message to author
			message join ' created with id #', $issue? 'Comment' : 'Issue', $id;

			# Notify other users
			foreach (grep { $_ ne $author } $self->roster('online')) {
				$self->message({
					to   => $_,
					body => $issue?
						"New comment #$id was added to issue #$issue by $author in $project":
						"New issue #$id was opened by $author in $project",
				});
			}
		}

		# Change issue status
		when ('mark') {
			my ($issue, $type) = split m{ +}, $args, 2;
			my $error;

			# Get target issue
			my ($response) = $vermishel->getMessage({ message => $issue });

			return error $response->{'error'}{'message'}
				if $response->{'error'};

			return message 'Wrong issue id'
				if $response->{'result'}{'meta'}{'type'} ne 'issue';

			$project = $response->{'result'}{'stream'};

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

			return error $response->{'error'}{'message'}
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

			return error $response->{'error'}{'message'}
				if $response->{'error'};

			# Send message to author
			message "Marked #$issue as $type";

			# Notify other users
			foreach (grep { $_ ne $author } $self->roster('online')) {
				$self->message({
					to   => $_,
					body => "Issue #$issue was marked as $type by $author in $project",
				});
			}
		}

		# Show issue or comment
		when ('show') {
			my (@results, $response, $issue);

			given ($args) {
				when (m{^\d+$}) {
					($response) = $vermishel->getMessage({ message => $args });

					return error $response->{'error'}{'message'}
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

						return message "Type $type was not found in project"
							unless $types->{$project}{$type};
					}

					# TODO: take number from config
					while (not @results % 50) {
						($response) = $vermishel->getLinkStream({ message => $issue || $types->{$project}{$type} });

						return error $response->{'error'}{'message'}
							if $response->{'error'};

						last unless push @results, @{ $response->{'result'}{'stream'} };
					}
				}
			}

			message join $/, map {
				sprintf '#%i (%i) %s', grep {
					s{</?\w+.*?>} {}ig or 1
				} @{ $_ }{qw{ id linked body }}
			} grep {
				not $issue or $_->{'meta'}{'type'} eq 'comment'
			} reverse @results;
		}

		# List user's projects
		when ('projects') {
			my (@subscriptions) = $redis->smembers($config->{'redis'}{'keys'}{'user'}{'subscriptions'}. $message->{'from'}); 

			return message join ', ', sort @subscriptions
				if @subscriptions;

			message 'No projects found';
		}

		# List all projects
		when ('list') {
			my (@projects) = $redis->smembers($config->{'redis'}{'keys'}{'streams'});

			return message join ', ', sort @projects
				if @projects;

			message 'No projects found';
		}

		# Manage project
		when ('project') {
			my ($project, $command, $args) = split m{ +}, $args, 3;

			return message 'Project name required'
				unless $project;

			given ($command) {
				# Reload and list all types
				when ('types') {
					my $error = types $project;

					return message $error
						if $error;

					message join ', ', sort { $types->{$project}{$a} <=> $types->{$project}{$b} } keys %{ $types->{$project} };
				}

				# Create new type
				when ('type') {
					my $type = $args;

					return message 'Type name required'
						unless $type;

					my $error = type $project, $type;

					return message $error
						if $error;

					message "New type $type was created";
				}

				# Grant access to project
				when ('grant') {
					my ($user) = split m{ +}, $args, 2;

					return message 'Jabber id required'
						unless $user;

					return message "User $user was not found in roster"
						unless grep { $_ eq $user } $self->roster();

					my $result = $redis->sadd($config->{'redis'}{'keys'}{'user'}{'subscriptions'}. $user, $project); 

					if ($result) {
						$self->message({
							to   => $user,
							body => "Access to $project granted",
						});

						message 'Access granted';
					} else {
						message "User $user already has access to $project";
					}
				}

				# Revoke access to project
				when ('revoke') {
					my ($user) = split m{ +}, $args, 2;

					return message 'Jabber id required'
						unless $user;

					my $result = $redis->srem($config->{'redis'}{'keys'}{'user'}{'subscriptions'}. $user, $project); 

					if ($result) {
						$self->message({
							to   => $user,
							body => "Access to $project revoked",
						}) if grep { $_ eq $user } $self->roster();

						message 'Access revoked';
					} else {
						message "User $user has no access to $project";
					}
				}

				# Create new project
				when ('create') {
					my ($response) = $vermishel->createStream({ stream => $project });

					return error $response->{'error'}{'message'}
						if $response->{'error'};

					message "Project $project created";
				}

				default {
					return message 'Read #help';
				}
			}
		}

		# Authentication
		when ('auth') {
			my $secret = md5_hex join ':', $$, $message->{'from'}, time, rand;
			my $url    = join '/auth?token=', $config->{'host'}, $secret;

			# Save token to redis
			$redis->setex($config->{'redis'}{'keys'}{'auth'}. $secret, 3600, $message->{'from'}, sub {});

			# Send auth url back
			message $url;
		}
	}
});

1;
