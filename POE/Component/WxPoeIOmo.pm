package WxPoeIOmo;
#######################################
#
#   This package creates a WxPoeIO object to manage signals between a Wx-Loop session and POE sessions
#     - a session is not started until it is requested via 'session_create'
#
#######################################
#   Package Credits
#######################################
#   is derived from...
####
# as of 2014.04.16:
# POE::Component::SimpleLog (v. 1.05), Perl extension to manage a simple logging system for POE
# Author: Apocalypse
####

####
# Notes: This object holds a single POE session. The [HEAP] container is not used.
#   Instead the [OBJECT]'s variables are used for state and data encapsulation.
#   The package is setup for use with both Moo and Moose...depending on you need for speed.
#   Signals may be triggered/tripped/fired by either a general 'pulse' call to the signal queue
#   or a direct method call to WxPoeIO.
####

# load a lightweight OO manager
use Mo qw[is default builder];

# load POE
use POE;

# Other miscellaneous modules
use Carp;


# Initialize our version
our $VERSION = '0.003011';

has 'this_version' => (isa => 'Num', is => 'ro', builder => '__set_version' );
has 'MY_SESSION' => (isa => 'Undef', is => 'rw', default => undef );
has 'ALIAS' => (isa => 'Str', is => 'rw', builder => '__set_alias' );
has 'MAIN_WXSERVER_ALIAS' => (isa => 'Str', is => 'ro');

# notices, alerts, run time messages
has 'LOG_SIGNAL_CONFIG' => (isa => 'Int', is => 'rw', default => 1 );
has 'LOG_WXPOEIO_START' => (isa => 'Int', is => 'rw', default => 1 );
has 'TRACE_WXPOEIO_START' => (isa => 'Int', is => 'rw', default => 0 );
has 'TRACE_SIGNAL_CONFIG' => (isa => 'Int', is => 'rw', default => 1 );
has 'TRACE_SIGNAL_REGISTRATION' => (isa => 'Int', is => 'rw', default => 1 );
has 'TRACE_SIGNAL_LATCH' => (isa => 'Int', is => 'rw', default => 0 );
has 'TRACE_SIGNAL_LOCK' => (isa => 'Int', is => 'rw', default => 0 );
has 'TRACE_SIGNAL_TRAP' => (isa => 'Int', is => 'rw', default => 0 );
has 'TRACE_SIGNAL_PATH_ALL' => (isa => 'Int', is => 'rw', default => 0 );
has 'TRACE_SIGNAL_PATH_SEL' => (isa => 'Int', is => 'rw', default => 1 );
has 'CROAK_WXPOEIO_START' => (isa => 'Int', is => 'rw', default => 1 );
has 'CROAK_ON_ERROR' => (isa => 'Int', is => 'rw', default => 1 );
has 'DIE_ON_ERROR' => (isa => 'Int', is => 'rw', default => 1 );
has 'TRACE_FILE_BASE_NAME' => (isa => 'Str', is => 'rw' );
has 'ACCEPT_SESSION_ID' => (isa => 'Int', is => 'rw', default => 0 );
#has 'SIGNAL_DUPLICATE_CARP' => (isa => 'Int', is => 'rw', default => 1 );

## default global values
has 'LOCK_TIMEOUT_DEFAULT' => (isa => 'Int', is => 'ro', default => 5 );
# The session registation tables
has 'WXPOEIO' => (isa => 'HashRef', is => 'rw', default => sub { {} });
has 'WXPOEIO_LOG' => (isa => 'HashRef', is => 'rw', default => sub { {} });
# SIGNAL_KEYS
has 'SIGNAL_KEYS' => (isa => 'HashRef', is => 'rw', default => sub { {} });
# The frame registration table
has 'WXFRAMEIO' => (isa => 'HashRef', is => 'rw', default => sub { {} });
# The channel registration table
has 'WXPOEIO_CHANNELS' => (isa => 'HashRef', is => 'rw', builder => '__set_channels');
# The channel wait lock table
has 'WXPOEIO_WAIT_CHANNEL_LOCK' => (isa => 'HashRef', is => 'rw', default => sub { {} });
# The signal wait latch table
has 'WXPOEIO_WAIT_SIGNAL_LATCH' => (isa => 'HashRef', is => 'rw', default => sub { {} });
# The message queue used by 'TRIGGER' to process signals
has 'WXPOEIO_QUEUE' => (isa => 'ArrayRef', is => 'rw', default => sub { [] });
# The temp holding message queue used by 'MANAGE_LOCKING' to re-submit signals
has 'WXPOEIO_QUEUE_TMP_HOLD' => (isa => 'ArrayRef', is => 'rw', default => sub { [] });
# The wxframe manager pointer
has 'WFRAME_MGR' => (isa => 'Undef', is => 'rw', default => undef );
# The Wx Main App pointer
has 'WX_MAIN_APP' => (isa => 'Undef', is => 'rw', default => undef );
# The signal results holding href
has 'WXFRAMEIO_RESULTS' => (isa => 'HashRef', is => 'rw', default => sub { {} });
## probably a bad idea...but it works
has 'KERNEL_PTR' => (isa => 'Undef', is => 'rw', default => undef );
# The process manager pointer
has 'PROCESS_MGR' => (isa => 'Undef', is => 'rw', default => undef );


## builder methods
sub __set_version {
	return $VERSION;
}
sub __set_alias {
	my $alias_index = 1;
	my $alias = __PACKAGE__ . "_" . $alias_index;
	return $alias;
}
sub __set_channels {
	my $opt = {};
	$opt->{MAIN} = undef;
	return $opt;
}

## admin methods
sub show_alias {
	my $self = shift;
	my $carp = 0;
	if(@_) {
		if($_[0]) { $carp = 1; }
	}
	print "[SHOW WXPOEIO ALIAS] This IO object is named: [".$self->{ALIAS}."]\n" if $carp;
	return $self->{ALIAS};
}
sub set_main_alias {
	my $self = shift;
	if(@_) { 
		my $alias = shift;
		if($alias) {
			$self->{MAIN_WXSERVER_ALIAS} = $alias;
		}
	}
	return $self->{MAIN_WXSERVER_ALIAS};
}
sub signal_queue_ptr {
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{WXPOEIO_QUEUE} = shift;
	}
	return $self->{WXPOEIO_QUEUE};
}
sub frame_mgr_ptr { ## remove
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{WXFRAME_MGR} = shift;
	}
	return $self->{WXFRAME_MGR};
}
sub wxframe_mgr_ptr { ## remove
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{WXFRAME_MGR} = shift;
	}
	return $self->{WXFRAME_MGR};
}
sub wx_main_app_ptr {
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{WX_MAIN_APP} = shift;
	}
	return $self->{WX_MAIN_APP};
}
sub process_mgr_ptr {
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{PROCESS_MGR} = shift;
	}
	return $self->{PROCESS_MGR};
}
sub set_alias {
	my $self = shift;
	if(@_) {
		$self->{ALIAS} = shift;
	}
	return $self->{ALIAS};
}


# Setup IO process
sub session_create {
	my $self = shift;

	# Sanity checking
	if ( @_ & 1 ) {
		croak( 'POE::Component::WxPoeIO->new needs even number of options' );
	}

	# The options hash
	my %opt = @_;

	# Our own options
	my ( $ALIAS, $MAIN_WXSERVER_ALIAS, $SIGNAL_KEYS, $QUEUE );

	# Get the session alias
	if ( exists $opt{ALIAS} ) {
		$self->{ALIAS} = $opt{ALIAS};
		delete $opt{ALIAS};
	} else {
		# Debugging info...
		if ( $self->{CROAK_WXPOEIO_START} ) {
			warn 'Using startup ALIAS = ['.$self->{ALIAS}.']';
		}
	}
	if($self->{CROAK_WXPOEIO_START}) {
		my $message = "[WXPOEIO START] using alias [".$self->{ALIAS}."]";
		$self->trace_message($message);
	}

	if ( exists $opt{MAIN_WXSERVER_ALIAS} ) {
		$self->{MAIN_WXSERVER_ALIAS} = $opt{MAIN_WXSERVER_ALIAS};
		delete $opt{MAIN_WXSERVER_ALIAS};
	} else {
		if(!$self->{MAIN_WXSERVER_ALIAS}) {
			# Set the default
			$self->{MAIN_WXSERVER_ALIAS} = 'MainWxPoeServer';
			# Debugging info...
			if ( $self->{CROAK_WXPOEIO_START} ) {
				warn 'Using default MAIN_WXSERVER_ALIAS = ['.$self->{MAIN_WXSERVER_ALIAS}.']';
			}
		}
	}
	if ( exists $opt{SIGNAL_QUEUE} ) {
		$self->{WXPOEIO_QUEUE} = $opt{SIGNAL_QUEUE};
		delete $opt{SIGNAL_QUEUE};
	} else {
		# Debugging info...
		if ( $self->{TRACE_WXPOEIO_START} ) {
			warn 'No signal queue imported. Using default array pointer.\n\tExport using EXPORT_SIG_QUEUE_PTR';
		}
	}
	
	# Get the signal keys defined by root script
	# These are held constant between Poe session and Wx frames
	if ( exists $opt{SIGNAL_KEYS} ) {
		# Check if it is defined
		if ( $opt{SIGNAL_KEYS} and $opt{SIGNAL_KEYS}=~/HASH/i ) {
			$self->{SIGNAL_KEYS} = $opt{SIGNAL_KEYS};
			delete $opt{SIGNAL_KEYS};
		} else {
			warn "WARNING! Setting of signal keys failed. Messaging process will not work.\n";
			return undef;
		}
	} else {
		warn "WARNING! Signal keys have not been set. Messaging process will not work.\n";
	}
	
	if ( exists $opt{TRACE_ALL_SIGNALS} ) {
		$self->{TRACE_SIGNAL_PATH_ALL} = 1;
		delete $opt{TRACE_ALL_SIGNALS};
	}

	# Anything left over is unrecognized
	if ( $self->{TRACE_WXPOEIO_START} ) {
		if ( keys %opt > 0 ) {
			croak 'Unrecognized options were present in POE::Component::WxPoeIO_moo->new -> ' . join( ', ', keys %opt );
		}
	}

	if($self->{TRACE_SIGNAL_PATH_ALL}) {
		my $message = "[WXPOEIO START] TRACE activated for all signals!";
		$self->trace_message($message);
	}

	# Create a new session for ourself
	$self->{MY_SESSION} = POE::Session->create(
		object_states	=>	[
			$self => {
			
				# Maintenance events
				'_start'	=>	"StartIO",
				'_stop'		=>	"_session_stop",

				# Config a signal [key] push for use...this is not the same as registing for a signal broadcast
				'CONFIG_SIGNAL'	=>	"Config_signal",

				# Register an IO signal session
				'REGISTER_SIGNAL'	=>	"Register_signal",

				# Unregister an IO session
				'UNREGISTER_SESSION'	=>	"UnRegister_session",

				# Register a wxframe to wxframe IO on FRAME_TO_FRAME channel
				'REGISTER_FRAME_TO_FRAME'	=>	"Register_frame_to_frame",

				# Trigger signals
				'TRIGGER_SIGNALS'		=>	'trigger_signals',

				# Fire a single signal
				'FIRE_SIGNAL'		=>	'fire_signal',

				# SIGNAL SOMETHING to POE!
				'_MANAGE_TO_POE'		=>	'_manage_to_poe',

				# Manage POE SIGNAL with wait loop for latched POE SIGNAL
				'_MANAGE_LATCHING'	=>	"_manage_latching",

				# Manage POE SIGNAL
				'_MANAGE_LOCKING'	=>	"_manage_locking",

				# Manage POE SIGNAL response with wait loop for trapped POE SIGNAL
				'_MANAGE_TRAPPING'	=>	"_manage_trapping",

				# Manage POE SIGNAL
				'_TO_POE'	=>	"_to_poe",

				# Manage POE SIGNAL
				'_TO_LOGGER'	=>	"_to_logger",

				# Wait loop for latched POE SIGNAL
				'_WAIT_ON_LOCK_TIMEOUT'	=>	"_wait_on_lock",

				# Wait loop for locked POE SIGNAL
				'_WAIT_POE_LOCK'	=>	"_wait_poe_lock",

				# Terminate signal and clean up state
				'END_SIGNAL'		=>	"_end_signal",

				# Fire a single signal
				'_CLEAR_SIGNAL'		=>	'_clear_signal',

				# Fire a single signal
				'_KILL_SIGNAL'		=>	'_kill_signal',

				# Set results of signal completion
				'SET_RESULTS_AND_END'		=>	"_set_results_and_end",

				# Send and update to WxFrame of new state
				'UPDATE_SIGNAL'		=>	'_update_signal',

				# SIGNAL SOMETHING to WxFrame!
				'TO_WX'			=>	"_toWx",

				# SIGNAL a value KEY to another WxFrame!
				'_TO_WXFRAME'			=>	"_toWxFrame",

				# Signal a message - POE to Wx - using a integer value message href
				'POE_MESSAGING'		=>	"_poe_messaging",

				# SIGNAL a value KEY to main_app directed WxFrame
				'_TO_WX_APP'			=>	"_to_wx_app",

				# export method to obtain the pointer to the signal queue
				'EXPORT_SIG_QUEUE_PTR' => "export_queue_ptr",

				# import method to set a pointer to the wxframe manager
				'SET_WX_MAIN_APP_PTR' => "import_wx_main_app_ptr",
				
				# We are done!
				'SHUTDOWN'	=>	"StopIO",
			},
		],
	);

	# Return success
	return 1;
}

# Configure a new io signal for latching and locking
sub Config_signal {
	# Get the arguments
#	my $args = $_[ ARG0 ];
	my( $self, $args ) = @_[ OBJECT, ARG0 ];

	my %loc_args = ('SIGNAL_CHANNEL'=>'MAIN','LATCH'=>1,'LATCH_TIMEOUT'=>0,'LOCK'=>0,'LOCK_TIMEOUT'=>10,'LOCK_RETRY_TIME'=>5,'TRACE_ME'=>0);

	if($self->{TRACE_SIGNAL_CONFIG}) {
		my $message = "[WXPOEIO CONFIG] config signal [".$args->{SIGNAL_KEY}."] size[".scalar(keys %$args)."] [$args]";
		$self->trace_message($message);
	}

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO - CONFIG] Did not get any configuration arguments";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
		}
		return undef;
	}

	if ( ! defined $args->{SIGNAL_CHANNEL} ) {
		if($self->{TRACE_SIGNAL_CONFIG}) {
			my $message = "[WXPOEIO CONFIG] no signal channel provided - using default MAIN for [".$args->{SIGNAL_KEY}."]";
			$self->trace_message($message);
		}
	}
	if ( exists $args->{SIGNAL_CHANNEL} and $args->{SIGNAL_CHANNEL} ) {
		$loc_args{SIGNAL_CHANNEL} = $args->{SIGNAL_CHANNEL};
	}
	if ( exists $args->{LATCH} and !$args->{LATCH} ) {
		$loc_args{LATCH} = 0;
	}
	if ( exists $args->{LATCH_TIMEOUT} and $args->{LATCH_TIMEOUT} ) {
		$loc_args{LATCH_TIMEOUT} = $args->{LATCH_TIMEOUT};
	}
	if ( exists $args->{LOCK} and $args->{LOCK} ) {
		$loc_args{LOCK} = 1;
	}
	## LOCK_TIMEOUT times out the lock as set
	if ( exists $args->{LOCK_TIMEOUT}) { # and $args->{LOCK_TIMEOUT} ) {
		$loc_args{LOCK_TIMEOUT} = $args->{LOCK_TIMEOUT};
	}
	## LOCK_RETRY_TIME counts off the number of times the lock is checked before dying
	if ( exists $args->{LOCK_RETRY_TIME} ) {
		if ( $args->{LOCK_RETRY_TIME} ) {
			$loc_args{LOCK_RETRY_TIME} = $args->{LOCK_RETRY_TIME};
		} elsif( defined $args->{LOCK_RETRY_TIME} and $args->{LOCK_RETRY_TIME} == 0 ) {
			# Force falsy state to be an integer 0
			$loc_args{LOCK_RETRY_TIME} = 0;
		}
	}
	if ( exists $args->{SIGNAL_IS_INACTIVE} and $args->{SIGNAL_IS_INACTIVE} ) {
		$loc_args{SIGNAL_IS_INACTIVE} = 1;
	}
	if ( exists $args->{SIGNAL_KILL_SIGVALUE} and defined $args->{SIGNAL_KILL_SIGVALUE} ) {
		$loc_args{SIGNAL_KILL_SIGVALUE} = $args->{SIGNAL_KILL_SIGVALUE};
	}
	if ( exists $args->{TRACE_ME}) { 
		$loc_args{TRACE_ME} = $args->{TRACE_ME};
	}

	if ( !exists $self->{SIGNAL_KEYS}->{ $args->{SIGNAL_KEY} } ) {
		warn 'Setting undefined SIGNAL KEY ['.$args->{SIGNAL_KEY}.']. Possible void context.';
		if($self->{TRACE_SIGNAL_CONFIG}) {
			my $message = "[WXPOEIO CONFIG] Signal key [".$args->{SIGNAL_KEY}."] not properly initialized";
			$self->trace_message($message);
		}
	}
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = $loc_args{SIGNAL_CHANNEL};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = $loc_args{LATCH};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK} = $loc_args{LOCK};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH_TIMEOUT} = $loc_args{LATCH_TIMEOUT};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK_TIMEOUT} = $loc_args{LOCK_TIMEOUT};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK_RETRY_TIME} = $loc_args{LOCK_RETRY_TIME};
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_LATCHED} = 0;
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRACE} = $loc_args{TRACE_ME};
	if ( exists $args->{SIGNAL_IS_INACTIVE} and $args->{SIGNAL_IS_INACTIVE} ) {
		$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED} = 1;
		#warn "[WXPOEIO CONFIG] sigkey[".$args->{SIGNAL_KEY}."] is set INACTIVE...use is blocked for signal [".$args->{SIGNAL_KEY}."] blocked[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED}."]\n" if $_[OBJECT]->{TRACE_WXPOEIO_START};
	}
	if ( exists $args->{SIGNAL_KILL_SIGVALUE} ) {
		## check for an indefinite lock [0] on LOCK_RETRY_TIME
		if(!$loc_args{LOCK_RETRY_TIME}) {
			$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SIGNAL_KILL_SIGVALUE} = $loc_args{SIGNAL_KILL_SIGVALUE};

			if($self->{TRACE_SIGNAL_CONFIG}) {
				my $message = "[WXPOEIO CONFIG] signal kill sigvalue for sigkey[".$args->{SIGNAL_KEY}."] is set to [".$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SIGNAL_KILL_SIGVALUE}."]";
				$self->trace_message($message);
			}
		}
	}
	## is there a signal response trap?
	if ( exists $args->{TRAP} and $args->{TRAP} ) {
		$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRAP} = 1;
		$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRAP_TIMEOUT} = 10;
		if ( exists $args->{TRAP_TIMEOUT} and $args->{TRAP_TIMEOUT} ) {
			$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRAP_TIMEOUT} = $args->{TRAP_TIMEOUT};
		}
	}

	if ( exists $args->{TRACE_SIGNAL} and $args->{TRACE_SIGNAL} ) {
		$self->{TRACE_SIGNAL_PATH_SEL} = 1;
		$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRACE} = 1;

		if($self->{TRACE_SIGNAL_CONFIG}) {
			my $message = "[WXPOEIO CONFIG] TRACE activated for sigkey[".$args->{SIGNAL_KEY}."] is set to [".$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TRACE}."]";
			$self->trace_message($message);
		}
	}

	if($self->{TRACE_SIGNAL_CONFIG}) {
		my $message = "[WXPOEIO CONFIG] lock timeout for sigkey[".$args->{SIGNAL_KEY}."]";
		$self->trace_message($message);
	}

#	if ( exists $args->{SENDBACK_NOTICE_NO_REGISTRATION} and $args->{SENDBACK_NOTICE_NO_REGISTRATION} ) {
#		$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SENDBACK_NOTICE_NO_REGISTRATION} = 1;
#	}

	if ( !exists $self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }  or !$self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } ) {
		$self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } = {};
	}

	if($self->{TRACE_SIGNAL_CONFIG}) {
		my $message = "[WXPOEIO CONFIG] sigkey[".$args->{SIGNAL_KEY}."] using WXPOEIO_CHANNELS channel [".$loc_args{SIGNAL_CHANNEL}."] for signal [".$args->{SIGNAL_KEY}."] [".$self->{WXPOEIO_CHANNELS}->{$loc_args{SIGNAL_CHANNEL}}."]";
		$self->trace_message($message);
	}
	$self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_LOCKED} = 0;
	$self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_NOISY} = 0;
	$self->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{NOISE} = undef;

	$self->{KERNEL_PTR} = $_[KERNEL];
	# Config complete!
	return 1;
}

# Register a session to watch/wait for io signal
sub Register_signal {
	# Get the arguments
	my( $self, $args ) = @_[ OBJECT, ARG0 ];

	my $carp = 1;
	if( exists $args->{CARP_REG} ) {
		$carp = $self->{TRACE_SIGNAL_REGISTRATION} = $args->{CARP_REG};
	}

	if($self->{TRACE_SIGNAL_REGISTRATION}) {
		my $message = "[WXPOE REGISTER SESS] registering session[".$args->{SESSION}."] for sigkey[".$args->{SIGNAL_KEY}."]";
		$self->trace_message($message);
	}

	# Validation - silently ignore errors...or not...
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOE REGISTER SESS] Did not get any session arguments";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
		}
		return undef;
	}
	if(exists $self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED} and $self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED}) {

		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS] this signal[".$args->{SIGNAL_KEY}."] is blocked - inactive - not registering";
			$self->trace_message($message);
		}

		return undef;
	}

	if ( ! defined $args->{SESSION} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOE REGISTER SESS] Did not get a TargetSession for SignalKey: ".$args->{SIGNAL_KEY};
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO WXPOE SESS] dying for a fix\n";
		}
		return undef;
	} else {
		# Convert actual POE::Session objects to their ID
		## not functional...not sure this option makes sense
		if ( UNIVERSAL::isa( $args->{SESSION}, 'POE::Session') ) {
			$args->{SESSION} = $args->{SESSION}->ID;
		}
	}
	$args->{LOG_SESSION} = $args->{SESSION};

	my $wxframe_mgr = 0;
	if ( exists $args->{WXFRAME_MGR_TOGGLE} ) {
		$wxframe_mgr = $args->{WXFRAME_MGR_TOGGLE};
	}

	my $frame = '_none_';
	if ( exists $args->{TARGET_WXFRAME_IDENT} ) {
		$frame = $args->{TARGET_WXFRAME_IDENT};
	}

	if ( defined $args->{EVT_METHOD_POE} or defined $args->{EVT_METHOD_LOG} or defined $args->{EVT_METHOD_WXFRAME}) {

		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS] [".$args->{SIGNAL_KEY}."] useable signal method available...complete registration";
			$self->trace_message($message);
		}
	} else {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOE REGISTER SESS] Did not get an Evt Method for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO WXPOE SESS] dying for a fix\n";
		}
		return undef;
	}
	
	####
	## possible future feature...note that client control is better managed by the WxPoeServer
	####
	if ( exists $args->{DIRECT_SERVER_SESSION_ALIASKEY} and $args->{DIRECT_SERVER_SESSION_ALIASKEY} ) {
		#$args->{SESSION} = $args->{DIRECT_SERVER_SESSION_ALIASKEY};
	}
	
	if ( defined $args->{EVT_METHOD_POE} ) {
		####
		## - register main session signal for an EVT_METHOD_POE (i.e., a method in the WxPoeServer)
		####
		if($args->{EVT_METHOD_POE}=~/^__([\w_\-]+)__$/) {

			if($self->{TRACE_SIGNAL_REGISTRATION}) {
				my $message = "[WXPOE REGISTER SESS] MAIN session for [".$args->{SIGNAL_KEY}."] this method [".$args->{EVT_METHOD_POE}."] [$1] belongs to the main session";
				$self->trace_message($message);
			}
			$args->{EVT_METHOD_POE} = $1;
			$args->{SESSION} = '_MAIN_WXSESSION_ALIAS_';
		}
		## - then register within the WXPOEIO hash structure
		if ( ! exists $self->{WXPOEIO}->{ $args->{SIGNAL_KEY} } ) {
			$self->{WXPOEIO}->{ $args->{SIGNAL_KEY} } = {};
		}
		if ( ! exists $self->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } ) {
				$self->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } = {};
		}

		# Store the POE event method in the signal key hash
		if ( exists $self->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE} ) {
			# Duplicate registration...
			if ( $self->{CROAK_ON_ERROR} ) {
				my $message = "[WXPOE REGISTER SESS] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Session[".$args->{SESSION}."] Event[".$args->{EVT_METHOD_POE}."] ... ignoring ";
				warn "$message";
				$self->log_message($message);
			}
			if ( $self->{DIE_ON_ERROR} ) {
				die "\t[WXPOEIO WXPOE SESS] dying for a fix\n";
			}
		} else {
			$self->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE} =  $args->{EVT_METHOD_POE};
			if($self->{TRACE_SIGNAL_REGISTRATION}) {
				my $message = "[WXPOE REGISTER SESS] [".$args->{SIGNAL_KEY}."] registering Poe Method [".$args->{EVT_METHOD_POE}."] under SESSION key [".$args->{SESSION}."]";
				$self->trace_message($message);
			}
		}
	}

	if( $frame !~ /^_none_$/i ) {

		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS - FRAME] registering frame [$frame] on [".$args->{SIGNAL_KEY}."]";
			$self->trace_message($message);
		}
		if ( ! defined $args->{EVT_METHOD_WXFRAME} ) {
			if ( $self->{CROAK_ON_ERROR} ) {
				my $message = "[WXPOE REGISTER SESS - FRAME] Did not get an WxEvtMethod for SignalKey: ".$args->{SIGNAL_KEY};
				warn "$message";
				$self->log_message($message);
			}
			if ( $self->{DIE_ON_ERROR} ) {
				die "\t[WXPOEIO WXPOE SESS - FRAME] dying for a fix\n";
			}
			return undef;
		}
		
		# register within the WXPOEIO hash structure
		if ( ! exists $self->{WXFRAMEIO}->{$frame} ) {
			$self->{WXFRAMEIO}->{$frame} = {};
		}

		if ( ! exists $self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
			$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
		}
		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS - FRAME] frame [$frame] registered for SignalKey: [".$args->{SIGNAL_KEY}."]";
			$self->trace_message($message);
		}

		# Finally store the wx method in the signal key method hash
		if ( ! exists $self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
			$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
		}
		$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{EVT_METHOD_WXFRAME} } = 1;

		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS - FRAME] frame [$frame] evt method[".$args->{EVT_METHOD_WXFRAME}."]";
			$self->trace_message($message);
		}

		# If an update method exists, store the wx update in the signal key method hash
		if( exists $args->{EVT_UPDATE_WXFRAME} and $args->{EVT_UPDATE_WXFRAME}) {
			if ( ! exists $self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE} ) {
				$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE} = {};
			}
			$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE}->{ $args->{EVT_UPDATE_WXFRAME} } = 1;

			if($self->{TRACE_SIGNAL_REGISTRATION}) {
				my $message = "[WXPOE REGISTER SESS - FRAME] frame [$frame] evt_up method[".$args->{EVT_UPDATE_WXFRAME}."]";
				$self->trace_message($message);
			}
		}

		if(!exists $self->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR}) {
			# set USE_WXFRAME_MGR to falsy as default
			$self->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
		}
		if($wxframe_mgr) {
			$self->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
		} else {
			$self->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
		}
		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS - FRAME] [$frame] all registered for SignalKey: [".$args->{SIGNAL_KEY}."]";
			$self->trace_message($message);
		}
	}


	if(exists $args->{EVT_METHOD_LOG} and $args->{EVT_METHOD_LOG}=~/^__([\w_\-]+)__$/) {

		if($self->{TRACE_SIGNAL_REGISTRATION}) {
			my $message = "[WXPOE REGISTER SESS - POE LOGGER] this method [".$args->{EVT_METHOD_LOG}."] [$1] belongs to the main session";
			$self->trace_message($message);
		}
		$args->{EVT_METHOD_LOG} = $1;
		$args->{LOG_SESSION} = '_MAIN_WXSESSION_ALIAS_';

		# register within the WXPOEIO hash structure
		if ( ! exists $self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} } ) {
			$self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} } = {};
		}
		if ( ! exists $self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} } ) {
				$self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} } = {};
		}

		# Store the POE event method in the signal key hash
		if ( exists $self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} }->{EVT_METHOD_LOG} ) {
			# Duplicate registration...
			if ( $self->{CROAK_ON_ERROR} ) {
				my $message = "[WXPOE REGISTER SESS] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Log Session[".$args->{LOG_SESSION}."] Event[".$args->{EVT_METHOD_LOG}."] ... ignoring ";
				warn "$message";
				$self->log_message($message);
			}
			if ( $self->{DIE_ON_ERROR} ) {
				die "\t[WXPOEIO WXPOE SESS] dying for a fix\n";
			}
			return undef;
		} else {
			$self->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} }->{EVT_METHOD_LOG} =  $args->{EVT_METHOD_LOG};
		}

	}
	
	# Also check for a FRAME event method in the signal key hash
#	if ( ! exists $args->{EVT_METHOD_WXFRAME} or ! $args->{EVT_METHOD_WXFRAME}) {
#	if (exists $args->{EVT_UPDATE_WXFRAME} and $args->{EVT_UPDATE_WXFRAME}) {
#		if ( exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_UPDATE_WXFRAME} ) {
#			# Duplicate record...
#			if ( $_[OBJECT]->{SIGNAL_DUPLICATE_CARP} ) {
#				#warn "Tried to register a duplicate! -> LogName: ".$args->{SIGNAL_KEY}." -> Target Session: ".$args->{SESSION}." -> Event: ".$args->{EVT_METHOD_WXFRAME};
#				warn "[WXPOEIO REGISTER] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Session[".$args->{SESSION}."] Event[".$args->{EVT_UPDATE_WXFRAME}."] ... ignoring  ";
#				return undef;
#			}
#		} else {
#			$_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_UPDATE_WXFRAME} =  $args->{EVT_UPDATE_WXFRAME};
#		#	print "[WXPOE REGISTER SESS] register UPDATE method [".$args->{EVT_UPDATE_WXFRAME}."] for signal[".$args->{SIGNAL_KEY}."]\n" if $carp;
#			print "[WXPOE REGISTER SESS] [".$args->{SIGNAL_KEY}."] registering UPDATE Method [".$args->{EVT_UPDATE_WXFRAME}."] under SESSION key [".$args->{SESSION}."]\n" if $carp;
#		}
#	}

	if($self->{TRACE_SIGNAL_REGISTRATION}) {
		my $message = "[WXPOE REGISTER SESS] registration COMPLETE for SignalKey: [".$args->{SIGNAL_KEY}."]";
		$self->trace_message($message);
	}
	# All registered!
	return 1;
}

# Delete a signal session (not tested)
## not sure how useful this method is. Unused signals do not seem significant.
sub UnRegister_session {
	# Get the arguments
#	my $args = $_[ ARG0 ];
	my( $self, $args ) = @_[ OBJECT, ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} or ! defined $args->{SESSION} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[UN-REGISTER WXPOE SESS] Did not get any proper arguments";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
		}
		return undef;
	}

	if ( ! defined $args->{EVT_METHOD_POE} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[UN-REGISTER WXPOE SESS] Did not get an EvtMethod for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
		}
		return undef;
	}

	# Search through the registrations for this specific one
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } ) {
		# Scan it for targetsession
		if ( exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } ) {
			# Scan for the proper event!
			foreach my $evt_meth ( keys %{ $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE} } ) {
				if ( $evt_meth eq $args->{EVT_METHOD_POE} ) {
					# Found a match, delete it!
					delete $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE};
					if ( scalar keys %{ $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } } == 0 ) {
						delete $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} };
					}

					# Return success
					return 1;
				}
			}
		}
	}

	# Found nothing...
	return undef;
}

# Register a frame to receive a signal on the FRAME_TO_FRAME channel (minimal latency between receipt and delivery)
sub Register_frame_to_frame {
	# Get the arguments
	my( $self, $args ) = @_[ OBJECT, ARG0 ];

	if($self->{TRACE_SIGNAL_REGISTRATION}) {
		my $message = "[REGISTER WXPOE SESS] registering frame to frame [".$args->{SIGNAL_KEY}."] size[".scalar(keys %$args)."] [$args]";
		$self->trace_message($message);
	}

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = undef;
	if ( exists $args->{TARGET_WXFRAME_IDENT} ) {
		$frame = $args->{TARGET_WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{EVT_METHOD_WXFRAME} ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			warn "Did not get an WxMethod for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	my $wxframe_mgr = 0;
	if ( exists $args->{WXFRAME_MGR_TOGGLE} ) {
		$wxframe_mgr = $args->{WXFRAME_MGR_TOGGLE};
	}
	
	# require either the use of a wxframe manager or the pointer to the wxframe object
	if ( ! defined $args->{WXFRAME_OBJ} and !$wxframe_mgr ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			warn "Did not get a WxFrame Object for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	}

	# register within the WXPOEIO hash structure
	if ( ! exists $self->{WXFRAMEIO}->{$frame} ) {
		$self->{WXFRAMEIO}->{$frame} = {};
	}

	if ( ! exists $self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
		$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
	}

	# Finally store the wx method in the signal key method hash
	if ( ! exists $self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
		$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
	}
	$self->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{EVT_METHOD_WXFRAME} } = 1;

	# set USE_WXFRAME_MGR to falsy as default
	$self->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
	if($wxframe_mgr) {
		$self->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
	} else {
		$self->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
	}

	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = 'FRAME_TO_FRAME';
	$self->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = 0;
	if ( !exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} ) {
		$self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} = {};
	}

	if($self->{TRACE_SIGNAL_REGISTRATION}) {
		my $message = "[REGISTER WXPOE SESS - FRAME-TO-FRAME] frame-to-frame registered for SignalKey: [".$args->{SIGNAL_KEY}."]";
		$self->trace_message($message);
	}
	# All registered!
	return 1;
}

# Where the work is queued...
sub trigger_signals {
	my $self = $_[ OBJECT ];

	if ( exists $self->{WXPOEIO_QUEUE} ) {
		my $sq = $self->{WXPOEIO_QUEUE};
		if($sq!~/ARRAY/i) {
			if ( $self->{CROAK_ON_ERROR} ) {
				my $message = "The siqnal queue pointer is corrupt: [$sq]. Will not trigger signals";
				warn "$message";
				$self->log_message($message);
			}
			if ( $self->{DIE_ON_ERROR} ) {
				die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
			}
			return undef;
		}
		while( scalar(@$sq) ) {
			my $signal = shift @$sq;

			if($self->{TRACE_SIGNAL_PATH_ALL}) {
				my $message = "[WXPOEIO] shifted off the signal queue -> href[$signal], remaining signals[".scalar(@$sq)."]";
				$self->trace_message($message);
			}

			if($signal!~/HASH/i) {
				if ( $self->{CROAK_ON_ERROR} ) {
					my $message = "The siqnal hash pointer is corrupt: [$signal]. Is not a hash reference. Cannot determine signal key and value";
					warn "$message";
					$self->log_message($message);
				}
				if ( $self->{DIE_ON_ERROR} ) {
					die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
				}
				next;
			}
			foreach my $sigkey (keys %$signal) {
				my $sigvalue = $signal->{$sigkey};
				if( !exists $self->{SIGNAL_KEYS}->{$sigkey}) {
					# warn...a potential configuration error
					warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
					if ( $self->{CROAK_ON_ERROR} ) {
						my $message = "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
						warn "$message";
						$self->log_message($message);
					}
					if ( $self->{DIE_ON_ERROR} ) {
						die "\t[WXPOEIO - TRIGGER] dying for a fix\n";
					}
					next;
				}
				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO] triggered: sigkey[$sigkey] val[$sigvalue]";
					$self->trace_message($message);
				}
#				print "[WXPOEIO] triggered: sigkey[$sigkey] val[$sigvalue]\n" 
				if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
					# check signal key against FRAME_TO_FRAME channel
					if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
						$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
						next;
					}
				}
				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO] sending sigkey[$sigkey] to_poe";
					$self->trace_message($message);
				}
				if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
					$self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = $signal;
				}
				$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
			}
			if(!scalar(@$sq)) {
				last;
			}
		}
		# signal queue is empty!
		return 1;
	}
	# silently fail falsy...tho, some notice should be given
	return 0;
}

# Fire a single signal
sub fire_signal {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue, $self ) = @_[ ARG0, ARG1, OBJECT ];
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO FIRE] fired: sigkey[$sigkey] val[$sigvalue]";
		$self->trace_message($message);
	}
	if( !exists $self->{SIGNAL_KEYS}->{$sigkey}) {
		# warn...a potential configuration error
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO FIRE] No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - FIRE] dying for a fix\n";
		}
		next;
	}
	if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
		# check signal key against FRAME_TO_FRAME channel
		if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
			$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
			next;
		}
	}
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO FIRE] sending sigkey[$sigkey] to_poe";
		$self->trace_message($message);
	}
	if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		$self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = {$sigkey => $sigvalue};
	}
	$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
	return;
}

# Fire a single signal to another frame
sub fire_interframe_signal {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue, $key ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO INTER-FIRE] fired: sigkey[$sigkey] val[$sigvalue]";
		$self->trace_message($message);
	}
	if( !exists $_[OBJECT]->{SIGNAL_KEYS}->{$sigkey}) {
		# warn...a potential configuration error
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO INTER-FIRE] No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - INTER-FIRE] dying for a fix\n";
		}
		next;
	}
	if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
		# check signal key against FRAME_TO_FRAME channel
		if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
			$_[KERNEL]->yield('_TO_WXFRAME', $sigkey, $sigvalue, $key);
			next;
		}
	}
	return;
}

# Fire a signal within an object method (method parameter must be a hash array)
# - will return an undefined value if signal is not active or registered
sub tripfire_signal {
	my $self = shift;
	my (%pms) = @_;
	my $carp = 0;
	if(exists $pms{trace}) {
		$carp = $pms{trace};
	}
	my $sigvalue = 0;
	if(exists $pms{sigvalue}) {
		$sigvalue = $pms{sigvalue};
	}
	if(!exists $pms{sigkey}) {
		## signal problem, return falsy
		return undef;
	}
	my $sigkey = $pms{sigkey};
	
	my $alias = $self->{ALIAS};
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO] tripfire: sigkey[$sigkey] val[$sigvalue]";
		$self->trace_message($message);
	}
	if( !exists $self->{SIGNAL_KEYS}->{$sigkey}) {
		# warn...a potential configuration error
		warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
		return undef;
	}
	
	if(exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_BLOCKED} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_BLOCKED}) {
		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[WXPOEIO] tripfire: this signal[".$sigkey."] is blocked - inactive - ignoring signal";
			$self->trace_message($message);
		}
#		print "[WXPOEIO] tripfire: this signal[".$sigkey."] is blocked - inactive - ignoring signal\n" if $carp;
#		if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SENDBACK_NOTICE_NO_REGISTRATION} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SENDBACK_NOTICE_NO_REGISTRATION} ) {
#			return {status=>-1,message=>'Signal is not registered/active'}
#		}
		return undef;
	}

	if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
		# check signal key against FRAME_TO_FRAME channel
		if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
			$self->{KERNEL_PTR}->post($alias, 'TO_WX', $sigkey, $sigvalue);
			return 1;
		}
	}
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO] tripfire: sending sigkey[$sigkey] to_poe";
		$self->trace_message($message);
	}
	if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		my $signal = {};
		$signal->{$sigkey} = $sigvalue;
		$self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = $signal;
	}
	
	## called method is not an event method, so the kernel ptr must be retrieved for event posting... 
	$self->{KERNEL_PTR}->post($alias, '_MANAGE_TO_POE', $sigkey, $sigvalue);
	
	return 1;
}

# Where the work is started...
sub _manage_to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[_MANAGE_TO_POE] check-in signal sigkey[$sigkey] val[$sigvalue]";
		$self->trace_message($message);
	}

	# Search for this signal!
	if ( exists $self->{WXPOEIO}->{ $sigkey } ) {

		# Test for signal latch
		#  latching discards a follow-on same signal until the latch expires.
		#  follow on signals are assumed to be bad signals

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[_MANAGE_TO_POE] check latch sigkey[$sigkey] val[$sigvalue]";
			$self->trace_message($message);
		}

		# Test for whether a latch has been specified for the signal call
		# if no latch, send for lock check
		if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} or !$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} ) {

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[_MANAGE_TO_POE] no latch on sigkey[$sigkey] sending to manage_locking";
				$self->trace_message($message);
			}

			$_[KERNEL]->yield('_MANAGE_LOCKING', $sigkey, $sigvalue);
			return 1;
		}
		
		# Latching is expected
		# Test for whether the signal call has been latched
		if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}  or !$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
			# no latch; set latch and continue to POE

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[_MANAGE_TO_POE] latch not yet set on sigkey[$sigkey] ... latched now!";
				$self->trace_message($message);
			}

			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 1;
			$self->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigkey} = 1;
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 1;
			$_[KERNEL]->delay('_MANAGE_LATCHING' => 1, $sigkey, $sigvalue);
			# send to manage_locking to check for locking
			$_[KERNEL]->yield('_MANAGE_LOCKING', $sigkey, $sigvalue);
			return 1;
		}

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[_MANAGE_TO_POE] sigkey[$sigkey] is latched, discarding this duplicate signal...doing nothing";
			$self->trace_message($message);
		}

	} else {
		# Ignore this signalkey
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[_MANAGE_TO_POE] Got this Signal_key: [$sigkey] -> Ignoring it because it is not registered!";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[_MANAGE_TO_POE] No SIGNAL, dying for a fix\n";
		}
		return 0;
	}

	# All done!
	return 1;
}

# manage (count-out) the latching here
sub _manage_latching {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	## check if latch is still in timeout
	## if signal reaches timeout, loop ends
	## a long latch could block new signals to quick duration tasks

	my $states = $self->{WXPOEIO_WAIT_SIGNAL_LATCH};
	my $count = 0;
	if($self->{TRACE_SIGNAL_LATCH} ) {
		my $message = "{WXPOEIO - MANAGE LATCH] manage the latch in-sigkey[$sigkey] ct[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
		$self->trace_message($message);
	}

	foreach my $sigkey (keys %$states) {
		if($self->{TRACE_SIGNAL_LATCH}) {
			my $message = " =[WXPOEIO - WAIT LATCH] for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
			$self->trace_message($message);
		}
		if($states->{$sigkey}) {
			$count++;
			if(!$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
				$count--;
				$states->{$sigkey} = 0;
				if($self->{TRACE_SIGNAL_LATCH}) {
					my $message = " ==[WXPOEIO - WAIT LATCH] latch *done* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
					$self->trace_message($message);
				}
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 0;
			}
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} + 1;
			if ( $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} > $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_TIMEOUT}) {
				$count--;
				$states->{$sigkey} = 0;
				if($self->{TRACE_SIGNAL_LATCH}) {
					my $message = " ==[WXPOEIO - WAIT LATCH] latch *count-out* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
					$self->trace_message($message);
				}
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 0;
			}
		}
	}
	if($count < 1) {
		return;
	}
	## continue until count goes to zero!
	$_[KERNEL]->delay('_MANAGE_LATCHING' => 1, $sigkey, $sigvalue);
	return 1;
}

# Manage channel locking
sub _manage_locking {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	# if signal requires a channel lock, check on lock and channel use (noise)
	my $channel = 'MAIN'; # default
	if ( exists $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}) {
		$channel = $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL};
	}
	if(!$channel) {
		# rats...something broke
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[_MANAGE_LOCKING] Darn! Looks like the channel value is null for this Signal_key: [$sigkey]";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[_MANAGE_LOCKING] No signal channel, dying for a fix\n";
		}
		return undef;
	}
	
	## check if channel locking is required
	if($self->{TRACE_SIGNAL_LOCK}) {
		my $message = "[_MANAGE_LOCKING] using channel [$channel] for signal [$sigkey]";
		$self->trace_message($message);
	}
	if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		## locking is required, check for lock...and channel noise 
		if($self->{TRACE_SIGNAL_LOCK}) {
			my $message = "[_MANAGE_LOCKING] lock required for channel [$channel], signal [$sigkey]";
			$self->trace_message($message);
		}
		if ( !exists $self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}  or !$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}) {
			## channel is unlocked, lock channel and send to POE
			if($self->{TRACE_SIGNAL_LOCK}) {
				my $message = "[_MANAGE_LOCKING] NEW lock state for channel [$channel], signal [$sigkey]";
				$self->trace_message($message);
			}
			if ( exists $self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}  and $self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}) {
				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[_MANAGE_LOCKING] channel [$channel] is in use, but no conflict for signal [$sigkey]";
					$self->trace_message($message);
				}
			} else {
				$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 1;
				$self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} = 1;
			}
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS} = 0;
			$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 1;
			$self->{WXPOEIO_CHANNELS}->{$channel}->{LOCK_SIGNAL} = {$sigkey => $sigvalue};
			$self->{WXPOEIO_WAIT_CHANNEL_LOCK}->{$channel} = 1;
			$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 1;
			$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
			$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT} = $self->{LOCK_TIMEOUT_DEFAULT};
			if(exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_TIMEOUT}) {
				$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT} = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_TIMEOUT};
			}

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[_MANAGE_LOCKING] signal [$sigkey] channel[$channel] lock now set for end-count[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}."], yield to_poe session.";
				$self->trace_message($message);
			}

			$_[KERNEL]->yield('_TO_POE', $sigkey, $sigvalue);

			if($self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}) {
				## an endcount of 0 means that the lock does not timeout.
				$_[KERNEL]->delay('_WAIT_ON_LOCK_TIMEOUT' => 1, $sigkey, $sigvalue);
			}
			return 1;
		}
		if( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_RETRY_TIME} ) {
			if( $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK_RETRY_TIME} ) {
				if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS}) {
					$self->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS} = 0;
				}
				$self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel}->{$sigkey} = 1;

				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[_MANAGE_LOCKING] lock state [".$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}."] for channel[$channel] signal [$sigkey]...validate signal for reset";
					$self->trace_message($message);
				}

				if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED}  or !$self->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED}) {
					$self->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED} = 1;
				}
				$self->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK}->{$sigkey} = 1;
				my $signal = $self->{WXPOEIO_CHANNELS}->{$channel}->{LOCK_SIGNAL}; # = {$sigkey => $sigvalue};
				foreach my $sigkey2 (keys %$signal) {
					my $sigvalue2 = $signal->{$sigkey2};
					
					if($self->{TRACE_SIGNAL_LOCK}) {
						my $message = "[_MANAGE_LOCKING] comparing signal; this signal[$sigkey]:tmp_hold_sig[$sigkey2] sigval[$sigvalue2]";
						$self->trace_message($message);
					}
					
					if($sigkey2=~/^$sigkey$/) {
						if($sigvalue2=~/^$sigvalue$/) {
							## drop this signal
							## do not use repeated signals to avoid creating race conditions or secondary errors

							if($self->{TRACE_SIGNAL_LOCK}) {
								my $message = "[_MANAGE_LOCKING] dropping this signal[$sigkey]:[$sigvalue]...cannot reset same signal";
								$self->trace_message($message);
							}

							$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);
							return 0;
						}
					}
				}
				my $signal_reload = {$sigkey => $sigvalue};

				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[_MANAGE_LOCKING] reloading this signal[$sigkey] into the siqnal queue";
					$self->trace_message($message);
				}

				my $sq = $self->{WXPOEIO_QUEUE_TMP_HOLD};
				push @$sq, $signal_reload;
				$_[KERNEL]->delay('_WAIT_POE_LOCK' => 1, $sigkey, $sigvalue, $channel);
				return 1;
			} elsif( $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK_RETRY_TIME} == 0 ) {
				# LOCK_RETRY_TIME set to [0]...indefinite lock!

				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[_MANAGE_LOCKING] indefinite lock state [".$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}."] for channel[$channel] - dropping signal [$sigkey]...swap signal for reset";
					$self->trace_message($message);
				}

				return 1;
			}
		}
	}
	$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 1;
	$self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} = 1;

	if($self->{TRACE_SIGNAL_LOCK}) {
		my $message = "[_MANAGE_LOCKING] WXPOEIO_CHANNELS channel [$channel] for signal [$sigkey] [".$self->{WXPOEIO_CHANNELS}->{$channel}."]";
		$self->trace_message($message);
	}

	$_[KERNEL]->yield('_TO_POE', $sigkey, $sigvalue);

	return 1;
}

# Where the work is finally send to POE...
sub _to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	# Now, loop over each possible poe session (poe alias), 
	foreach my $TSession ( keys %{ $self->{WXPOEIO}->{$sigkey} } ) {

		my $evt_method = $_[OBJECT]->{WXPOEIO}->{$sigkey}->{$TSession}->{EVT_METHOD_POE};
		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[TO_POE] found session alias [$TSession] for signal [$sigkey] session[".$self->{MAIN_WXSERVER_ALIAS}."] evt_method[$evt_method]";
			$self->trace_message($message);
		}

		my $PSession = undef;
		my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
		if($TSession=~/_MAIN_WXSESSION_ALIAS_/i) {
			$PSession = $self->{MAIN_WXSERVER_ALIAS};
#			my $evt_meth = $self->{WXPOEIO}->{$sigkey}->{$TSession}->{EVT_METHOD_POE};

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[TO_POE] use main session [$TSession] at alias [$PSession] method[$evt_method] for signal [$sigkey] session[".$self->{MAIN_WXSERVER_ALIAS}."]";
				$self->trace_message($message);
			}
		} else {

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[TO_POE] target session [$TSession] is not _MAIN_ for signal [$sigkey]";
				$self->trace_message($message);
			}
			
			$PSession = $TSession;
			if($self->{ACCEPT_SESSION_ID}) {
				# Find out if this session exists
				if ( $_[KERNEL]->ID_id_to_session( $TSession ) ) {
					if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
						my $message = "[TO_POE] using SESSION_ID [$TSession] to trigger evt_meth[$evt_method] for signal [$sigkey]";
						$self->trace_message($message);
					}
				} elsif(defined $_[KERNEL]->alias_resolve($TSession)) {
					my $ts = $_[KERNEL]->alias_resolve($TSession);
					$PSession = $_[KERNEL]->ID_session_to_id( $ts );
				}

				$_[KERNEL]->post(	$PSession,
									$evt_method,
									$sigkey,
									$sigvalue,
								);
				return 1;
			}
			
		}

		# Send signal to event method
		$_[KERNEL]->post(	$PSession,
							$evt_method,
							$sigkey,
							$sigvalue,
				);
		return 1;

	}
	return 0;
}

# Where the poe message work is started...
sub _poe_messaging {
	# ARG0 = signal_key, ARG1 = integer_value, [Optional, ARG2 = message hash]
	my( $self, $sigkey, $intval, $mess_href ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[_MANAGE_TO_POE] check-in signal sigkey[$sigkey] intval[$intval]";
		$self->trace_message($message);
	}

	# Search for this signal!
	if ( exists $self->{WXPOEIO}->{ $sigkey } ) {

		# Test for signal trap
		#  trapping discards a follow-on same signal until the trap expires.
		#  follow on signals are assumed to be bad signals

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[_POE_MESSAGING] check trap for sigkey[$sigkey]";
			$self->trace_message($message);
		}

		# Test for whether a trap has been specified for the signal call
		# if no trap, send to wxframe (no signal locking on POE side)
		if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP} or !$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP} ) {

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[_POE_MESSAGING] no trap on sigkey[$sigkey] sending to wx_frames";
				$self->trace_message($message);
			}

			$_[KERNEL]->yield('_TO_WX_APP', $sigkey, $intval, $mess_href);
			return 1;
		}
		
		# Trapping is expected
		# Test for whether the signal call has been trapped
		if ( !exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED}  or !$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED}) {
			# no latch; set latch and continue to POE

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[_POE_MESSAGING] trap not yet set on sigkey[$sigkey] ... trapped now!";
				$self->trace_message($message);
			}

			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED} = 1;
			$self->{WXPOEIO_WAIT_SIGNAL_TRAP}->{$sigkey} = 1;
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} = 1;
			$_[KERNEL]->delay('_MANAGE_TRAPPING' => 1, $sigkey, $intval);

			# send to wx_frames for message handling
			$_[KERNEL]->yield('_TO_WX_APP', $sigkey, $intval, $mess_href);
			return 1;
		}

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[_POE_MESSAGING] sigkey[$sigkey] is trapped, discarding this duplicate signal...doing nothing";
			$self->trace_message($message);
		}

	} else {
		# Ignore this signalkey
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[_POE_MESSAGING] Got this Signal_key: [$sigkey] -> Ignoring it because it is not registered!";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[_POE_MESSAGING] No SIGNAL, dying for a fix\n";
		}
		return 0;
	}

	# All done!
	return 1;
}


# Stow the results of to_poe signal...and send response (end signal)
sub _set_results_and_end {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _results_hash_reference_]
	my( $self, $sigkey, $sigvalue, $res_href ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];

	my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
	$self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
	$self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
	$self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF} = undef;
	$self->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = '_default_';
	if($res_href=~/HASH/i) {
		if(exists $res_href->{status}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = $res_href->{status};
			delete $res_href->{status};
		}
		if(exists $res_href->{message}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = $res_href->{message};
			delete $res_href->{message};
		}
		if(exists $res_href->{href}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF} = $res_href->{href};
			delete $res_href->{href};
		}
		if(exists $res_href->{layout_obj_method}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = $res_href->{layout_obj_method};
			delete $res_href->{layout_obj_method};
		}
	}
	undef $res_href;
	
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO SET RESULTS] for signal [$sigkey][$key] status[".$self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}."] mess[".$self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE}."]";
		$self->trace_message($message);
	}
	
	$_[KERNEL]->yield('END_SIGNAL', $sigkey, $sigvalue);
	return;
}

# Where the work is finished...
sub _end_signal {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO END SIGNAL] end of signal[".$sigkey."] - send response to wxframe,  clear signal";
		$self->trace_message($message);
	}

	# Check for valid signal!
	if ( ! exists $self->{WXPOEIO}->{ $sigkey } ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO END SIGNAL] Darn! No valid signal set for sigkey[$sigkey]";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO END SIGNAL] sigkey not configured, dying for a fix\n";
		}
		return undef;
	}

	####
	## signal response trap code goes here...
	####
	## check for trap {TRAP}
	if ( exists $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{TRAP} and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{TRAP} ) {
		
		## sanity check...make sure trap timeout is valid
		if( exists $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{TRAPTIMEOUT} and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{TRAP_TIMEOUT} > 0 ) {

			## if trap is valid, check for {IS_TRAPPED}
			if ( exists $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{IS_TRAPPED} and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{IS_TRAPPED} ) {
				## if is_trapped, return undef
				return undef;
			}
			
			## otherwise...set trap loop -> MANAGE_TRAPPING
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED} = 1;
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} = 0;
			$_[KERNEL]->yield('_MANAGE_TRAPPING', $sigkey, $sigvalue);
		}
	}
	
	# clear all latch, locks and noise for signal
	$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);


	if ( exists $self->{WXPOEIO_LOG}->{ $sigkey } ) {
		$_[KERNEL]->yield('_TO_LOGGER', $sigkey, $sigvalue);
	}

	# signal sent to wxframe, close loop
#	print "[WXPOEIO] send response to_wx [".$sigkey."]\n";
	$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
	return 1;
}

# Where incremental updates of the signal work is returned...
sub _update_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $self, $sigkey, $sigvalue, $res_href ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	
	my $update = 1;
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO UPDATE SIGNAL] update - send signal notice [".$sigkey."] update signal[$update]";
		$self->trace_message($message);
	}

	# Check for valid signal!
	if ( ! exists $self->{WXPOEIO}->{ $sigkey } ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO UPDATE SIGNAL] Darn! No valid signal set for sigkey[$sigkey]";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO UPDATE SIGNAL] sigkey not configured, dying for a fix\n";
		}
	}

	my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
	$self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
	$self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
	if($res_href=~/HASH/i) {
		if(exists $res_href->{status}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = $res_href->{status};
			delete $res_href->{status};
		}
		if(exists $res_href->{message}) {
			$self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = $res_href->{message};
			delete $res_href->{message};
		}
		if(scalar(keys %$res_href)) {
			foreach my $rkey (keys %$res_href) {
				$self->{WXFRAMEIO_RESULTS}->{$key}->{$rkey} = $res_href->{$rkey};
				delete $res_href->{$rkey};
			}
		}
	}
	undef $res_href;

	# signal sent to wxframe, close loop
	$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue, $update);
	return 1;
}

# Where notice of result is send to the wxFrame...
sub _toWx {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $self, $sigkey, $sigvalue, $update ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO TO-WX] send signal notice [".$sigkey."]";
		if($update) { $message = $message . " update signal[$update]"; }
		$self->trace_message($message);
	}

	# Search through the registrations for this specific one
	foreach my $wxframe ( keys %{ $self->{WXFRAMEIO} } ) {
		# Scan frame key for signal key
		if ( exists $self->{WXFRAMEIO}->{$wxframe}->{$sigkey} ) {
			# Scan for the proper evt_method!
			## first check for if this is an update notice
			if($update) {
				foreach my $evt_up ( keys %{ $self->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_UPDATE} } ) {
				
					if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
						my $message = "[WXPOEIO TO-WX] found update method[$evt_up] for frame [$wxframe] for sigkey[$sigkey]";
						$self->trace_message($message);
					}

					my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
					my $status = 0;
					my $dhref = undef;
					my $message = 'null';
					my %base_keys = (STATUS => 1, MESSAGE => 1, DHREF => 1);
					foreach my $bkey (keys %base_keys) {
						if(!$base_keys{$bkey}) { next; }
						if($bkey=~/STATUS/) {
							$status = $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
							delete $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
						}
						if($bkey=~/MESSAGE/) {
							$message = $self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
							delete $self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
						}
						if($bkey=~/DHREF/) {
							$dhref = $self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF};
							$self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF} = undef;
						}
					}
					if(!defined $self->{WX_MAIN_APP}) {
						warn "[WXPOEIO - To WX] failed to find Main App ptr. Application fails...at line [".__LINE__."]\n";
						die "\tdying to fix...\n";
						## else, fail silently...nothing is returned to the wxframe
						return undef;
					}
					my $wxframe_obj = $self->{WX_MAIN_APP}->getWxFramePtr($wxframe);
					if( my $ref = eval { $wxframe_obj->can($evt_up) } ) {
						$wxframe_obj->$evt_up( $sigkey, $sigvalue, $status, $message, $dhref );
					}
				}
				return 1;
			}
			foreach my $evt_meth ( keys %{ $self->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_METHODS} } ) {

				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO TO-WX] found evt method[$evt_meth] for frame [$wxframe] for sigkey[$sigkey]";
					$self->trace_message($message);
				}

				my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
				my $status = 0;
				my $dhref = undef;
				my $message = 'null';
				my %base_keys = (STATUS => 1, MESSAGE => 0, DHREF => undef);
				foreach my $bkey (keys %base_keys) {
						if(!$base_keys{$bkey}) { next; }
						if($bkey=~/STATUS/) {
							$status = $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
							delete $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
						}
						if($bkey=~/MESSAGE/) {
							$message = $self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
							delete $self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
						}
						if($bkey=~/DHREF/) {
							$dhref = $self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF};
							$self->{WXFRAMEIO_RESULTS}->{$key}->{DHREF} = undef;
						}
					}
				my $data_method = '_default_';
				if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
					# check signal key against FRAME_TO_FRAME channel
					if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
						$status = 1;
						$message = '';
						$dhref = undef;
					}
				}
				if(!defined $self->{WX_MAIN_APP}) {
					warn "[WXPOEIO - To WX] failed to find Main App ptr. Application fails...at line [".__LINE__."]\n";
					die "\tdying to fix...\n";
					## else, fail silently...nothing is returned to the wxframe
					return undef;
				}
				my $wxframe_obj = $self->{WX_MAIN_APP}->getWxFramePtr($wxframe);
				if( my $ref = eval { $wxframe_obj->can($evt_meth) } ) {
					$wxframe_obj->$evt_meth( $sigkey, $sigvalue, $status, $dhref, $message, );
				} else {
					if ( $self->{CROAK_ON_ERROR} ) {
						my $message = "[WXPOEIO TO-WX] Opps! No valid event method [$evt_meth] defined within wxFrame for sigkey[$sigkey]";
						warn "$message";
						$self->log_message($message);
					}
					if ( $self->{DIE_ON_ERROR} ) {
						die "\t[WXPOEIO TO-WX] evt_method [$evt_meth] not configured, dying for a fix\n";
					}
					next;
				}
			}
		}
	}
	return 1;
}

# Where INTER-FRAME work is done...
sub _toWxFrame {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = data_key]
	my( $self, $sigkey, $sigvalue, $key ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO INTERWXFRAME] send signal response [".$sigkey."]";
		if(defined $key) { $message = $message . " datakey[$key]"; }
		$self->trace_message($message);
	}

	# Search through the registrations for this specific one
	foreach my $wxframe ( keys %{ $_[OBJECT]->{WXFRAMEIO} } ) {
		# Scan frame key for signal key
		if ( exists $_[OBJECT]->{WXFRAMEIO}->{$wxframe}->{$sigkey} ) {
			# Scan for the proper evt_method!
			foreach my $evt_up ( keys %{ $_[OBJECT]->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_UPDATE} } ) {

				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO TO-WXFRAME] found interframe evt method[$evt_up] for frame [$wxframe] for sigkey[$sigkey]";
					$self->trace_message($message);
				}

				if(!$key) { $key = 0; } ## send a falsy key as default
				if(defined $_[OBJECT]->{WXFRAME_MGR}) {
					my $wxframe_obj = $_[OBJECT]->{WXFRAME_MGR}->frame_handle_by_key($wxframe);
					$wxframe_obj->$evt_up( $sigkey, $sigvalue, $key, );
				}
				## else, fail silently...nothing is return to the wxframe
			}
		}
	}
	return 1;
}

# Where notice of message is send to the wxFrame via the Main App...
sub _to_wx_app {
	# ARG0 = signal_key, ARG1 = integer_value, [Optional, ARG2 = message hash]
	my( $self, $sigkey, $intval, $mess_href ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO TO_WX_APP] check-in signal sigkey[$sigkey] intval[$intval]";
		$self->trace_message($message);
	}

	# Search through the registrations for this specific one
	foreach my $wxframe ( keys %{ $self->{WXFRAMEIO} } ) {
		# Scan frame key for signal key
		if ( exists $self->{WXFRAMEIO}->{$wxframe}->{$sigkey} ) {
			# Scan for the proper evt_method!
			## first check for if this is an update notice
			foreach my $evt_meth ( keys %{ $self->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_METHODS} } ) {

				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO TO_WX_APP] found evt method[$evt_meth] for frame [$wxframe] for sigkey[$sigkey]";
					$self->trace_message($message);
				}

				if(!defined $self->{WX_MAIN_APP}) {
					warn "[WXPOEIO TO_WX_APP] failed to find Main App ptr. Application fails...at line [".__LINE__."]\n";
					die "\tdying to fix...\n";
					## else, fail silently...nothing is returned to the wxframe
					return undef;
				}
				my $wxframe_obj = $self->{WX_MAIN_APP}->getWxFramePtr($wxframe);
				if( my $ref = eval { $wxframe_obj->can($evt_meth) } ) {
					$wxframe_obj->$evt_meth( $intval, $mess_href, $sigkey, );
				} else {
					if ( $self->{CROAK_ON_ERROR} ) {
						my $message = "[WXPOEIO TO_WX_APP] Opps! No valid event method [$evt_meth] defined within wxFrame for sigkey[$sigkey]";
						warn "$message";
						$self->log_message($message);
					}
					if ( $self->{DIE_ON_ERROR} ) {
						die "\t[WXPOEIO TO_WX_APP] evt_method [$evt_meth] not configured, dying for a fix\n";
					}
					next;
				}
			}
		}
	}
	return 1;

}

# And send SIGNAL RESULT to POE LOGGER SESSION...
sub _to_logger {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[WXPOEIO TO-LOGGER] send signal results to logger session [".$sigkey."]";
		$self->trace_message($message);
	}

	my $res_href = {};
	$res_href->{STATUS} = 0;
	$res_href->{MESSAGE} = 'No results';
	my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
	if(exists $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}) {
		$res_href->{STATUS} = $self->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
		$res_href->{MESSAGE} = $self->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
		$res_href->{LAYOUT_OBJ_METHOD} = $self->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD};
	}

	# Now, loop over each possible poe session (poe alias), 
	foreach my $TSession ( keys %{ $self->{WXPOEIO_LOG}->{$sigkey} } ) {
		my $PSession = undef;
		my $evt_meth = $self->{WXPOEIO_LOG}->{$sigkey}->{$TSession}->{EVT_METHOD_LOG};
		if($TSession=~/_MAIN_WXSESSION_ALIAS_/i) {
			$PSession = $self->{MAIN_WXSERVER_ALIAS};

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				my $message = "[WXPOEIO TO-LOGGER] use main session [$TSession] at alias [$PSession] meth[$evt_meth] for signal [$sigkey] [".$self->{MAIN_WXSERVER_ALIAS}."]";
				$self->trace_message($message);
			}

			$_[KERNEL]->post(	$PSession,
								$evt_meth,
								$sigkey,
								$sigvalue,
								$res_href,
					);
			return 1;
		}

		$PSession = $TSession;
		if($self->{ACCEPT_SESSION_ID}) {
			# Find out if this session exists
			if ( $_[KERNEL]->ID_id_to_session( $TSession ) ) {
				if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
					my $message = "[WXPOEIO TO-LOGGER] using SESSION_ID [$TSession] to trigger evt_meth[$evt_meth] for signal [$sigkey]";
					$self->trace_message($message);
				}
			} elsif(defined $_[KERNEL]->alias_resolve($TSession)) {
				my $ts = $_[KERNEL]->alias_resolve($TSession);
				$PSession = $_[KERNEL]->ID_session_to_id( $ts );
			}

			$_[KERNEL]->post(	$PSession,
								$evt_meth,
								$sigkey,
								$sigvalue,
								$res_href,
							);
			return 1;
		}

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[WXPOEIO TO-LOGGER] session post, to alias[$PSession] to trigger evt_meth[$evt_meth] for signal [$sigkey]";
			$self->trace_message($message);
		}

		# Send signal to event method
		$_[KERNEL]->post(	$PSession,
							$evt_meth,
							$sigkey,
							$sigvalue,
							$res_href,
				);
		return 1;

	}
	return 0;
}

# Clear signal settings
sub _clear_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[_CLEAR_SIGNAL] clear this signal [".$sigkey."]";
		$self->trace_message($message);
	}

	# Check for valid signal!
	if ( ! exists $self->{WXPOEIO}->{ $sigkey } ) {
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[WXPOEIO - CLEAR SIGNAL] Darn! No valid signal set for sigkey[$sigkey]";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[WXPOEIO - CLEAR SIGNAL] sigkey not configured, dying for a fix\n";
		}
		return undef;
	}

	my $channel = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};
	if( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} and defined $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} ) {
		if( $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} != $sigvalue) {
			## this signal set is not able to terminate the lock on this signal/channel
			if ( $self->{CROAK_ON_ERROR} ) {
				my $message = "[WXPOEIO - CLEAR SIGNAL] this sigkey[$sigkey] and sigval[$sigvalue] != sigkillvalue[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE}."] - cannot kill lock on channel[$channel].";
				warn "$message";
				$self->log_message($message);
			}
			return 1;
		}
	}

	$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
	$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

	if ( exists $self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} and $self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} ) {
		$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
	}

	if ( exists $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
		delete $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
	}
		
	# clear all latch, locks and noise for signal
	
	my $message = "[_CLEAR_SIGNAL]";
	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		$message = $message . " filtering channel [".$channel."]";
	}

	if ( scalar keys %{ $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
		$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			$message = $message . ", clearing channel noise";
		}
	}

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		$message = $message . ", channel [".$channel."] clear";
		$self->trace_message($message);
	}

	if ( exists $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel} and scalar(keys $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel})) {
		my $states = $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel};
		foreach my $sig (keys %$states) {
			if($states->{$sig}) {
				$states->{$sig} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sig}->{WAIT_BLOCKED} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sig}->{RETRY_ATTEMPTS} = 0;
			}
		}
	}
		
	return 1;
}

# Timeout a signal call to a locked channel
sub _wait_poe_lock {
	# ARG0 = signal_key, ARG1 = signal_value, ARG2 = signal channel
	my( $self, $sigkey, $sigvalue, $channel ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];

	## must check for whether the lock has been cleared during the delay to poe_lock
	## if the lock is clear, re-submit signal and trigger signals
	## if the wait time has expired, let signal die
	my $states = $self->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK};
	my $count = 0;
	if($self->{TRACE_SIGNAL_LOCK}) {
		my $message = "[WXPOEIO LOCK_WAIT-ON] wait for lock release [$sigkey]";
		$self->trace_message($message);
	}

	foreach my $sig_key (keys %$states) {
		if($self->{TRACE_SIGNAL_LOCK}) {
			my $message = "=[WXPOEIO LOCK_WAIT LOOP] for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}."] not_done[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]";
			$self->trace_message($message);
		}
		if($states->{$sig_key}) {
			$count++;
			if(	!$self->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}) {
				$count++;
				$states->{$sig_key} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} = 0;

				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "=[WXPOEIO LOCK_WAIT LOOP] wait-lock completed for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}."] not_done[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]";
					$self->trace_message($message);
				}
			}
			$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}++;
			if($self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} > $self->{SIGNAL_KEY_HREF}->{$sig_key}->{LOCK_RETRY_TIME}) {
				$count--;
				$states->{$sig_key} = 0;

				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "=[WXPOEIO LOCK_WAIT LOOP] wait-lock counted out for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}."] not_done[".$self->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]";
					$self->trace_message($message);
				}
				$self->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} = 0;
			}
		}
	}
	if($count < 1) {
		return;
	}
	my $sq_tmp = $self->{WXPOEIO_QUEUE_TMP_HOLD};
	my $sq = $self->{WXPOEIO_QUEUE};
	my $message_more = undef;
	if($self->{TRACE_SIGNAL_LOCK}) {
		$message_more = "[WXPOEIO LOCK_WAIT-ON] lock release for sigkey[$sigkey], sigkey back onto sigqueue [";
	}
	while(scalar(@$sq_tmp)) {
		my $signal = shift @$sq_tmp;
		push @$sq, $signal;
		## must terminate any latches...bitches, they are...
		foreach my $sigk (keys %$signal) {
			if(exists $self->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk} and $self->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk}) {
				## kill sigkey latch...
				$self->{SIGNAL_KEY_HREF}->{$sigk}->{IS_LATCHED} = 0;
				$self->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk} = 0;
			}
			if($self->{TRACE_SIGNAL_LOCK}) {
				$message_more = $message_more . $sigk . ",";
			}
		}
	}
	if($self->{TRACE_SIGNAL_LOCK}) {
		$message_more = $message_more . "] - trigger signals";
		$self->trace_message($message_more);
	}
	$_[KERNEL]->yield('TRIGGER_SIGNALS');
	return 1;
}

# timeout channel locking here
sub _wait_on_lock {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	my $states = $self->{WXPOEIO_WAIT_CHANNEL_LOCK};
	my $count = 0;

	if($self->{TRACE_SIGNAL_LOCK}) {
		my $message = "[WXPOEIO CHANNEL LOCK] sigkey lock release [$sigkey]";
		$self->trace_message($message);
	}

	foreach my $channel (keys %$states) {
		if($self->{TRACE_SIGNAL_LOCK}) {
			my $message = "[WXPOEIO LOCK LOOP] for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]";
			$self->trace_message($message);
		}
		if($states->{$channel}) {
			$count++;
			if(!$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}) {
				$count--;
				$states->{$channel} = 0;
				$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[WXPOEIO LOCK LOOP] lock completed for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]";
					$self->trace_message($message);
				}
			}
			$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}++;
			if($self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} > $self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}) {
				$count--;
				$states->{$channel} = 0;
				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = "[WXPOEIO LOCK LOOP] lock counted out for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]";
					$self->trace_message($message);
				}
				$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
				$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
				$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);
			}
		}
	}
	if($count < 1) {
		return;
	}
	## continue until count goes to zero!
	my $channel = 'MAIN'; # default
	if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL}  and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL}) {
		$channel = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};
	}

	if($self->{TRACE_SIGNAL_LOCK}) {
		my $message = "=[WXPOEIO LOCK LOOP] wait on sigkey[$sigkey] lock - lock count [".$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."]";
		$self->trace_message($message);
	}

	$_[KERNEL]->delay('_WAIT_ON_LOCK_TIMEOUT' => 1, $sigkey, $sigvalue);
	return 1;
}

# Kill signal settings - use to clear a DNS start/stop signal 
sub _kill_signal {
	# ARG0 = signal_key, ARG1 = signal_value, 
	my( $self, $sigkey, $sigvalue ) = @_[ OBJECT, ARG0, ARG1 ];

	if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
		my $message = "[_KILL_SIGNAL] kill this signal [".$sigkey."]";
		$self->trace_message($message);
	}

	# Search for this signal!
	if ( exists $self->{WXPOEIO}->{ $sigkey } ) {

		# clear all latch, locks and noise for signal
		my $channel = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};

		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			my $message = "[_KILL_SIGNAL] filtering channel [".$channel."] [".$sigkey."]";
			$self->trace_message($message);
		}

		$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
		$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

		if ( exists $self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} and $self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} ) {
			$self->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
		}

		if ( exists $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
			delete $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
		}

		my $message_more = undef;
		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			$message_more = "[_KILL_SIGNAL] clear signal latch, clear lock, clear wait, clear signal noise";
		}
		
		if ( scalar keys %{ $self->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
			$self->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;

			if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
				$message_more = $message_more . ", clear channel noise";
			}
		}
		if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
			$message_more = $message_more . " [".$channel."]";
			$self->trace_message($message_more);
		}

		if ( exists $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel} and scalar(keys $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel})) {
			my $states = $self->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel};
			foreach my $sig (keys %$states) {
				if($states->{$sig}) {
					$states->{$sig} = 0;
#					$_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK}->{$sig} = 0;

					if($self->{TRACE_SIGNAL_PATH_ALL} or ($self->{TRACE_SIGNAL_PATH_SEL} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRACE}) ) {
						my $message =  "=[_KILL_SIGNAL] clear block for sig[$sig] on channel[$channel]";
						$self->trace_message($message);
					}

					$self->{SIGNAL_KEY_HREF}->{$sig}->{WAIT_BLOCKED} = 0;
					$self->{SIGNAL_KEY_HREF}->{$sig}->{RETRY_ATTEMPTS} = 0;
				}
			}
		}
		
	} else {
		# Ignore this signalkey
		if ( $self->{CROAK_ON_ERROR} ) {
			my $message = "[_KILL_SIGNAL] Got this signal_key: [$sigkey] -> Ignoring it because it is not registered!";
			warn "$message";
			$self->log_message($message);
		}
		if ( $self->{DIE_ON_ERROR} ) {
			die "\t[_KILL_SIGNAL] No SIGNAL to kill, dying for a fix\n";
		}
		return 0;
	}
	return 1;
}

# manage (count-out) the trapping here
sub _manage_trapping {
	# ARG0 = signal_key, [optional: ARG1 = integer_value]
	my( $self, $sigkey, $intval ) = @_[ OBJECT, ARG0, ARG1 ];

	## check if trap is still in timeout
	## if trap reaches timeout, loop ends
	## a long trap could block new responses for quick duration tasks

	if(!exists $self->{WXPOEIO_WAIT_SIGNAL_TRAP}) {
		## no traps set...ignore call
		return undef;
	}
	
	my $states = $self->{WXPOEIO_WAIT_SIGNAL_TRAP};
	my $count = 0;
	
	if($self->{TRACE_SIGNAL_LOCK}) { ## use TRACE_SIGNAL_LOCK setting...this setting should be mostly off (falsy)
		my $message = "{WXPOEIO - MANAGE TRAP] manage the trap back-sigkey[$sigkey] ct[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
		$self->trace_message($message);
	}

	foreach my $sigkey (keys %$states) {

		if($self->{TRACE_SIGNAL_LOCK}) {
			my $message = " =[WXPOEIO - WAIT TRAP] for back-sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]";
			$self->trace_message($message);
		}
		if($states->{$sigkey}) {
			$count++;
			if(!$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED}) {
				$count--;
				$states->{$sigkey} = 0;
				
				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = " ==[WXPOEIO - WAIT TRAP] trap *done* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS}."]";
					$self->trace_message($message);
				}
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} = 0;
			}
			$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} = $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} + 1;
			if ( $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} > $self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_TIMEOUT}) {
				$count--;
				$states->{$sigkey} = 0;
				
				if($self->{TRACE_SIGNAL_LOCK}) {
					my $message = " ==[WXPOEIO - WAIT TRAP] trap *count-out* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS}."]";
					$self->trace_message($message);
				}
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_TRAPPED} = 0;
				$self->{SIGNAL_KEY_HREF}->{$sigkey}->{TRAP_ATTEMPTS} = 0;
			}
		}
	}
	if($count < 1) {
		return;
	}
	## continue until count goes to zero!
	$_[KERNEL]->delay('_MANAGE_TRAPPING' => 1, $sigkey, $intval);
	return 1;
}

# Starts the WxPoe IO
sub StartIO {
	# Create an alias for ourself
	$_[KERNEL]->alias_set( $_[OBJECT]->{'ALIAS'} );

	# All done!
	return 1;
}

# Stops the WxPoe IO
sub StopIO {
	# Remove our alias
	$_[KERNEL]->alias_remove( $_[OBJECT]->{ALIAS} );

	# Clear our data
	$_[OBJECT]->{WXPOEIO} = undef;
	$_[OBJECT]->{WXFRAMEIO} = undef;
	$_[OBJECT]->{WXPOEIO} = {};
	$_[OBJECT]->{WXFRAMEIO} = {};
	# All done!
	return 1;
}

sub _session_stop {
	my $heap = $_[HEAP];
	if ($heap->{listener}) {
		delete $heap->{listener};
	}
	if ($heap->{session}) {
		delete $heap->{session};
	}
	if ($_[OBJECT]->{MY_SESSION}) {
		delete $_[OBJECT]->{MY_SESSION};
	}
	exit;
}

sub export_queue_ptr {
	my $queue_var = $_[ ARG0 ];
	if(!exists $_[OBJECT]->{WXPOEIO_QUEUE}) {
		$_[OBJECT]->{WXPOEIO_QUEUE} = [];
	}
	$queue_var = $_[OBJECT]->{WXPOEIO_QUEUE};
	return 1;
}

sub import_wx_main_app_ptr {
	my $ptr_var = $_[ ARG0 ];
	if(!exists $_[OBJECT]->{WX_MAIN_APP}) {
		$_[OBJECT]->{WX_MAIN_APP} = $ptr_var;
	}
	$_[OBJECT]->{WX_MAIN_APP} = $ptr_var;
	return 1;
}

sub trace_message {
	my $self = shift;
	my $message = shift;
	if(defined $self->{TRACE_FILE_BASE_NAME}) {
		## send to a trace file
		if(defined $self->{PROCESS_MGR}) {
			## send to logger method in process manager
			my $_pmgr = $self->{PROCESS_MGR};
			$_pmgr->log_signal_trace_tstamp_yml(ymlstr => $message);
		} else {
			## method is not done!
		}
		return 1;
	}
	print $message . "\n";
	return 1;
}

sub log_message {
	my $self = shift;
	my $message = shift;
	if(defined $self->{PROCESS_MGR}) {
		## send to logger method in process manager
		my $_pmgr = $self->{PROCESS_MGR};
		$_pmgr->log_signal_runtime_tstamp_yml(ymlstr => $message);
		return 1;
	}
	return 0;
}

# End of module
1;
