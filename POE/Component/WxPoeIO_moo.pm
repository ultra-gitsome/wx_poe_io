package WxPoeIO_moo;
#######################################
#
#   This package creates a WxPoeIO object to manage signals between a Wx-Loop session and POE sessions
#     - a session is not started until it is requested via 'session_create'
#
#######################################
#   Package Credits
#######################################
#   this package is derived from...
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

#use Moo;
use Moose;
use POE;
# Other miscellaneous modules
use Carp;


# Initialize our version
our $VERSION = '0.002001';

has 'this_version' => (isa => 'Num', is => 'ro', builder => '__set_version' );
has 'MY_SESSION' => (isa => 'Undef', is => 'rw', default => undef );
has 'RUNTIME_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'STARTUP_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'SIGNAL_LOOP_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'SIGNAL_DUPLICATE_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'SIGNAL_LOOP_DETAILS_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'SIGNAL_LATCH_CARP' => (isa => 'Int', is => 'rw', default => 0 );
has 'SIGNAL_LOCK_CARP' => (isa => 'Int', is => 'rw', default => 0 );
has 'CLEAR_SIGNAL_CARP' => (isa => 'Int', is => 'rw', default => 0 );
has 'UPDATING_CARP' => (isa => 'Int', is => 'rw', default => 1 );
has 'TOWX_CARP' => (isa => 'Int', is => 'rw', default => 0 );
has 'ALIAS' => (isa => 'Str', is => 'rw', builder => '__set_alias' );
has 'MAIN_WXSERVER_ALIAS' => (isa => 'Str', is => 'ro');
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
# The signal results holding href
has 'WXFRAMEIO_RESULTS' => (isa => 'HashRef', is => 'rw', default => sub { {} });
## probably a bad idea...but it works
has 'KERNEL_PTR' => (isa => 'Undef', is => 'rw', default => undef );


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
sub frame_mgr_ptr {
	my $self = shift;
	if(@_) {
		## no error checking...
		$self->{WXFRAME_MGR} = shift;
	}
	return $self->{WXFRAME_MGR};
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
	my ( $ALIAS, $MAIN_WXSERVER_ALIAS, $SIGNAL_KEYS, $QUEUE, $LOOP_CARP );

	# Get the session alias
	if ( exists $opt{ALIAS} ) {
		$self->{ALIAS} = $opt{ALIAS};
		delete $opt{ALIAS};
	} else {
		# Debugging info...
		if ( $self->{STARTUP_CARP} ) {
			warn 'Using startup ALIAS = ['.$self->{ALIAS}.']';
		}
	}
	if ( exists $opt{MAIN_WXSERVER_ALIAS} ) {
		$self->{MAIN_WXSERVER_ALIAS} = $opt{MAIN_WXSERVER_ALIAS};
		delete $opt{MAIN_WXSERVER_ALIAS};
	} else {
		if(!$self->{MAIN_WXSERVER_ALIAS}) {
			# Set the default
			$self->{MAIN_WXSERVER_ALIAS} = 'MainWxPoeServer';
			# Debugging info...
			if ( $self->{STARTUP_CARP} ) {
				warn 'Using default MAIN_WXSERVER_ALIAS = ['.$self->{MAIN_WXSERVER_ALIAS}.']';
			}
		}
	}
	if ( exists $opt{SIGNAL_QUEUE} ) {
		$self->{WXPOEIO_QUEUE} = $opt{SIGNAL_QUEUE};
		delete $opt{SIGNAL_QUEUE};
	} else {
		# Debugging info...
		if ( $self->{STARTUP_CARP} ) {
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
	
	if ( exists $opt{SIGNAL_LOOP_CARP} ) {
		$self->{SIGNAL_LOOP_CARP} = $opt{SIGNAL_LOOP_CARP};
		delete $opt{SIGNAL_LOOP_CARP};
	}

	# Anything left over is unrecognized
	if ( $self->{STARTUP_CARP} ) {
		if ( keys %opt > 0 ) {
			croak 'Unrecognized options were present in POE::Component::WxPoeIO_moo->new -> ' . join( ', ', keys %opt );
		}
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

				# Register an IO session
				'REGISTER_SESSION'	=>	"Register_session",

				# Unregister an IO session
				'UNREGISTER_SESSION'	=>	"UnRegister_session",

				# Register an IO frame
				'REGISTER_FRAME'	=>	"Register_frame",

				# Unregister an IO frame
				'UNREGISTER_FRAME'	=>	"UnRegister_frame",

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

				# export method to obtain the pointer to the signal queue
				'EXPORT_SIG_QUEUE_PTR' => "export_queue_ptr",

				# import method to set a pointer to the wxframe manager
				'SET_WXFRAME_MGR' => "import_frame_mgr_ptr",
				
				# We are done!
				'SHUTDOWN'	=>	"StopIO",
			},
		],
	);
#	) or return undef;

	# Do not use [HEAP] for state variable
	# Use [OBJECT] variables to manage object processes
	#### 'heap'		=>	{ }


	# Return success
	return 1;
}

# Configure a new io signal for latching and locking
sub Config_signal {
	# Get the arguments
	my $args = $_[ ARG0 ];

	my %loc_args = ('SIGNAL_CHANNEL'=>'MAIN','LATCH'=>1,'LATCH_TIMEOUT'=>0,'LOCK'=>0,'LOCK_TIMEOUT'=>10,'LOCK_RETRY_TIME'=>5);

	print "[CONFIG WXPOEIO] config signal [".$args->{SIGNAL_KEY}."] size[".scalar(keys %$args)."] [$args]\n" if $_[OBJECT]->{STARTUP_CARP};
	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}

	if ( ! defined $args->{SIGNAL_CHANNEL} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a signal channel for signal: ".$args->{SIGNAL_KEY}." - using default [MAIN] channel";
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

	if ( !exists $_[OBJECT]->{SIGNAL_KEYS}->{ $args->{SIGNAL_KEY} } ) {
		warn 'Setting undefined SIGNAL KEY ['.$args->{SIGNAL_KEY}.']. Possible void context.';
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Signal key ['.$args->{SIGNAL_KEY}.'] not properly initialized';
		}
	}
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = $loc_args{SIGNAL_CHANNEL};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = $loc_args{LATCH};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK} = $loc_args{LOCK};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH_TIMEOUT} = $loc_args{LATCH_TIMEOUT};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK_TIMEOUT} = $loc_args{LOCK_TIMEOUT};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK_RETRY_TIME} = $loc_args{LOCK_RETRY_TIME};
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_LATCHED} = 0;
	if ( exists $args->{SIGNAL_IS_INACTIVE} and $args->{SIGNAL_IS_INACTIVE} ) {
		$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED} = 1;
		print "[CONFIG WXPOEIO] sigkey[".$args->{SIGNAL_KEY}."] is set INACTIVE...use is blocked for signal [".$args->{SIGNAL_KEY}."] blocked[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED}."]\n" if $_[OBJECT]->{STARTUP_CARP};
	}
	if ( exists $args->{SIGNAL_KILL_SIGVALUE} ) {
		## check for an indefinite lock [0] on LOCK_RETRY_TIME
		if(!$loc_args{LOCK_RETRY_TIME}) {
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SIGNAL_KILL_SIGVALUE} = $loc_args{SIGNAL_KILL_SIGVALUE};
			print "[CONFIG WXPOEIO] signal kill sigvalue for sigkey[".$args->{SIGNAL_KEY}."] is set to [".$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SIGNAL_KILL_SIGVALUE}."] \n" if $_[OBJECT]->{STARTUP_CARP};
		}
	}
	print "[CONFIG WXPOEIO] lock timeout for sigkey[".$args->{SIGNAL_KEY}."] is set to [".$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK_TIMEOUT}."] \n" if $_[OBJECT]->{STARTUP_CARP};
	if ( exists $args->{SENDBACK_NOTICE_NO_REGISTRATION} and $args->{SENDBACK_NOTICE_NO_REGISTRATION} ) {
		$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{SENDBACK_NOTICE_NO_REGISTRATION} = 1;
	}
	if ( !exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }  or !$_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } ) {
		$_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } = {};
	}
	print "[CONFIG WXPOEIO] sigkey[".$args->{SIGNAL_KEY}."] using WXPOEIO_CHANNELS channel [".$loc_args{SIGNAL_CHANNEL}."] for signal [".$args->{SIGNAL_KEY}."] [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$loc_args{SIGNAL_CHANNEL}}."]\n" if $_[OBJECT]->{STARTUP_CARP};
	$_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_LOCKED} = 0;
	$_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_NOISY} = 0;
	$_[OBJECT]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{NOISE} = undef;

	$_[OBJECT]->{KERNEL_PTR} = $_[KERNEL];
	# Config complete!
	return 1;
}

# Register a session to watch/wait for io signal
sub Register_session {
	# Get the arguments
	my $args = $_[ ARG0 ];

	my $carp = 0;
	if( exists $args->{CARP_REG} ) {
		$carp = $args->{CARP_REG};
	}
	print "[REGISTER WXPOE SESS] registering session[".$args->{SESSION}."] for sigkey[".$args->{SIGNAL_KEY}."]\n" if $carp;

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	if(exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED} and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED}) {
		print "[REGISTER WXPOE SESS] this signal[".$args->{SIGNAL_KEY}."] is blocked - inactive - not registering\n" if $carp;
		return undef;
	}

	if ( ! defined $args->{SESSION} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a TargetSession for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	} else {
		# Convert actual POE::Session objects to their ID
		if ( UNIVERSAL::isa( $args->{SESSION}, 'POE::Session') ) {
			$args->{SESSION} = $args->{SESSION}->ID;
		}
	}
	$args->{LOG_SESSION} = $args->{SESSION};
	if ( defined $args->{EVT_METHOD_POE} or defined $args->{EVT_METHOD_LOG} or defined $args->{EVT_METHOD_WXFRAME}) {
		print "[REGISTER WXPOE SESS] [".$args->{SIGNAL_KEY}."] useable signal method available...complete registration\n" if $carp;
	} else {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get an EvtMethod for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
		}
		return undef;
	}
	if($args->{EVT_METHOD_POE}=~/^__([\w_\-]+)__$/) {
		print "[REGISTER WXPOE SESS] [".$args->{SIGNAL_KEY}."] this method [".$args->{EVT_METHOD_POE}."] [$1] belongs to the main session\n" if $carp;
		$args->{EVT_METHOD_POE} = $1;
		$args->{SESSION} = '_MAIN_WXSESSION_ALIAS_';
	}

#	# register within the WXPOEIO hash structure
	if ( ! exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } ) {
		$_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } = {};
	}

	if ( ! exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } ) {
			$_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } = {};
	}

	# Store the POE event method in the signal key hash
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE} ) {
		# Duplicate record...
		if ( $_[OBJECT]->{SIGNAL_DUPLICATE_CARP} ) {
			warn "[WXPOEIO REGISTER] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Session[".$args->{SESSION}."] Event[".$args->{EVT_METHOD_POE}."] ... ignoring  ";
			return undef;
		}
	} else {
		$_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_METHOD_POE} =  $args->{EVT_METHOD_POE};
		print "[REGISTER WXPOE SESS] [".$args->{SIGNAL_KEY}."] registering Poe Method [".$args->{EVT_METHOD_POE}."] under SESSION key [".$args->{SESSION}."]\n" if $carp;
	}

	if(exists $args->{EVT_METHOD_LOG} and $args->{EVT_METHOD_LOG}=~/^__([\w_\-]+)__$/) {
		print "[REGISTER POE LOGGER SESS FRAME] this method [".$args->{EVT_METHOD_LOG}."] [$1] belongs to the main session\n" if $carp;
		$args->{EVT_METHOD_LOG} = $1;
		$args->{LOG_SESSION} = '_MAIN_WXSESSION_ALIAS_';

		# register within the WXPOEIO hash structure
		if ( ! exists $_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} } ) {
			$_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} } = {};
		}
		if ( ! exists $_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} } ) {
				$_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} } = {};
		}

		# Store the POE event method in the signal key hash
		if ( exists $_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} }->{EVT_METHOD_LOG} ) {
			# Duplicate record...
			if ( $_[OBJECT]->{SIGNAL_DUPLICATE_CARP} ) {
				warn "[WXPOEIO REGISTER] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Session[".$args->{LOG_SESSION}."] Event[".$args->{EVT_METHOD_LOG}."] ... ignoring  ";
				return undef;
				#warn "Tried to register a duplicate! -> LogName: ".$args->{SIGNAL_KEY}." -> Target Session: ".$args->{LOG_SESSION}." -> Event: ".$args->{EVT_METHOD_LOG};
			}
		} else {
			$_[OBJECT]->{WXPOEIO_LOG}->{ $args->{SIGNAL_KEY} }->{ $args->{LOG_SESSION} }->{EVT_METHOD_LOG} =  $args->{EVT_METHOD_LOG};
		}
	}
	
	# Also check for a FRAME event method in the signal key hash
#	if ( ! exists $args->{EVT_METHOD_WXFRAME} or ! $args->{EVT_METHOD_WXFRAME}) {
	if (exists $args->{EVT_UPDATE_WXFRAME} and $args->{EVT_UPDATE_WXFRAME}) {
		if ( exists $_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_UPDATE_WXFRAME} ) {
			# Duplicate record...
			if ( $_[OBJECT]->{SIGNAL_DUPLICATE_CARP} ) {
				#warn "Tried to register a duplicate! -> LogName: ".$args->{SIGNAL_KEY}." -> Target Session: ".$args->{SESSION}." -> Event: ".$args->{EVT_METHOD_WXFRAME};
				warn "[WXPOEIO REGISTER] Duplicate signal -> sigkey[".$args->{SIGNAL_KEY}."] Session[".$args->{SESSION}."] Event[".$args->{EVT_UPDATE_WXFRAME}."] ... ignoring  ";
				return undef;
			}
		} else {
			$_[OBJECT]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{EVT_UPDATE_WXFRAME} =  $args->{EVT_UPDATE_WXFRAME};
		#	print "[REGISTER WXPOE SESS] register UPDATE method [".$args->{EVT_UPDATE_WXFRAME}."] for signal[".$args->{SIGNAL_KEY}."]\n" if $carp;
			print "[REGISTER WXPOE SESS] [".$args->{SIGNAL_KEY}."] registering UPDATE Method [".$args->{EVT_UPDATE_WXFRAME}."] under SESSION key [".$args->{SESSION}."]\n" if $carp;
		}
	}

	print "[REGISTER WXPOE SESS] all registered for SignalKey: [".$args->{SIGNAL_KEY}."]\n" if $carp;
	# All registered!
	return 1;
}

# Delete a watcher session
sub UnRegister_session {
	# Get the arguments
	my $args = $_[ ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	if ( ! defined $args->{SESSION} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a TargetSession for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	} else {
		# Convert actual POE::Session objects to their ID
		if ( UNIVERSAL::isa( $args->{SESSION}, 'POE::Session') ) {
			$args->{SESSION} = $args->{SESSION}->ID;
		}
	}

	if ( ! defined $args->{EVT_METHOD_POE} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get an EvtMethod for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
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

# Register a wxframe to watch/wait for io signal
sub Register_frame {
	# Get the arguments
	my $args = $_[ ARG0 ];

	print "registering frame [".$args->{SIGNAL_KEY}."] size[".scalar(keys %$args)."] [$args]\n";
	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	if(exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED} and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_BLOCKED}) {
		print "[REGISTER WXPOE SESS] this signal[".$args->{SIGNAL_KEY}."] is blocked - inactive - not registering\n";
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	print "registering frame [$frame] on [".$args->{SIGNAL_KEY}."] \n";
	if ( ! defined $frame ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}," and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{EVT_METHOD_WXFRAME} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get an WxMethod for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	my $wxframe_mgr = 0;
	if ( exists $args->{WXFRAME_MGR_TOGGLE} ) {
		$wxframe_mgr = $args->{WXFRAME_MGR_TOGGLE};
	}
	# require either the use of a wxframe manager or the pointer to the wxframe object
#	if ( ! defined $args->{WXFRAME_OBJ} and !$wxframe_mgr ) {
#		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
#			warn "Did not get a WxFrame Object for SignalKey: ".$args->{SIGNAL_KEY};
#		}
#		return undef;
#	}


	# register within the WXPOEIO hash structure
	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame} ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame} = {};
	}

	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
	}
	print "[WXPOEIO - REG F] frame [$frame] registered for SignalKey: [".$args->{SIGNAL_KEY}."]\n";

	# Finally store the wx method in the signal key method hash
	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
	}
	$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{EVT_METHOD_WXFRAME} } = 1;
	print "[WXPOEIO - REG F] evt methods, evt[".$args->{EVT_METHOD_WXFRAME}."]";

	# Finally store the wx method in the signal key method hash
	if( exists $args->{EVT_UPDATE_WXFRAME} and $args->{EVT_UPDATE_WXFRAME}) {
		if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE} ) {
			$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE} = {};
		}
		$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_UPDATE}->{ $args->{EVT_UPDATE_WXFRAME} } = 1;
		print ", evt_up[".$args->{EVT_UPDATE_WXFRAME}."]";
	}

	# set USE_WXFRAME_MGR to falsy as default
	$_[OBJECT]->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
	if($wxframe_mgr) {
		$_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
	} else {
		$_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
	}
	print " registered for SignalKey: [".$args->{SIGNAL_KEY}."]\n";

	# All registered!
	return 1;
}

# Delete a watcher frame
sub UnRegister_frame {
	# Get the arguments
	my $args = $_[ ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{EVT_METHOD_WXFRAME} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get an WxMethod for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}

	# Search through the registrations for this specific one
	if ( exists $_[OBJECT]->{WXFRAMEIO}->{$frame} ) {
		# Scan it for signal key
		if ( exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
			# Scan for the proper event!
			foreach my $evt_meth ( keys %{ $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} } ) {
				if ( $evt_meth eq $args->{EVT_METHOD_WXFRAME} ) {
					# Found a match, delete it!
					delete $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $evt_meth };
					if ( scalar keys %{ $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} } == 0 ) {
						delete $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS};
						if ( scalar keys %{ $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } } == 0 ) {
							delete $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} };
							if ( scalar keys %{ $_[OBJECT]->{WXFRAMEIO}->{$frame} } == 0 ) {
								delete $_[OBJECT]->{WXFRAMEIO}->{$frame};
								if( exists $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} ) {
									delete $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR};
								}
								if( exists $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} ) {
									delete $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ};
								}
								if ( scalar keys %{ $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame} } == 0 ) {
									delete $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame};
								}
							}
						}
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
	my $args = $_[ ARG0 ];
	print "registering frame to frame [".$args->{SIGNAL_KEY}."] size[".scalar(keys %$args)."] [$args]\n";

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{EVT_METHOD_WXFRAME} ) {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
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
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Did not get a WxFrame Object for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	}

	# register within the WXPOEIO hash structure
	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame} ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame} = {};
	}

	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
	}

	# Finally store the wx method in the signal key method hash
	if ( ! exists $_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
		$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
	}
	$_[OBJECT]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{EVT_METHOD_WXFRAME} } = 1;

	# set USE_WXFRAME_MGR to falsy as default
	$_[OBJECT]->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
	if($wxframe_mgr) {
		$_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
	} else {
		$_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
	}

	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = 'FRAME_TO_FRAME';
	$_[OBJECT]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = 0;
	if ( !exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} ) {
		$_[OBJECT]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} = {};
	}

	print "frame-to-frame registered for SignalKey: [".$args->{SIGNAL_KEY}."]\n";
	# All registered!
	return 1;
}

# Where the work is queued...
sub trigger_signals {

	if ( exists $_[OBJECT]->{WXPOEIO_QUEUE} ) {
#		print "got a signal to trigger? ct[".@$sq."]\n";
		my $sq = $_[OBJECT]->{WXPOEIO_QUEUE};
		if($sq!~/ARRAY/i) {
			if ( $_[OBJECT]->{RUNTIME_CARP} ) {
				warn "The siqnal queue pointer is corrupt: [$sq]. Will not trigger signals";
			}
			return undef;
		}
		while( scalar(@$sq) ) {
			my $signal = shift @$sq;
			print "[WXPOEIO] signal trigger href?[$signal]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

			if($signal!~/HASH/i) {
				if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
					warn "The siqnal hash pointer is corrupt: [$signal]. Cannot determine signal key and value";
				}
				next;
			}
			foreach my $sigkey (keys %$signal) {
				my $sigvalue = $signal->{$sigkey};
				print "[WXPOEIO] triggered: sigkey[$sigkey] val[$sigvalue]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
				if( !exists $_[OBJECT]->{SIGNAL_KEYS}->{$sigkey}) {
					# warn...a potential configuration error
					warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
					next;
				}
				if( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
					# check signal key against FRAME_TO_FRAME channel
					if($_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
						$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
						next;
					}
				}
				print "[WXPOEIO] sending sigkey[$sigkey] to_poe\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
				if ( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = $signal;
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
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];
	print "[WXPOEIO FIRE] fired: sigkey[$sigkey] val[$sigvalue]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
	if( !exists $_[OBJECT]->{SIGNAL_KEYS}->{$sigkey}) {
		# warn...a potential configuration error
		warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
		next;
	}
	if( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
		# check signal key against FRAME_TO_FRAME channel
		if($_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
			$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
			next;
		}
	}
	print "[WXPOEIO FIRE] sending sigkey[$sigkey] to_poe\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
	if ( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = {$sigkey => $sigvalue};
	}
	$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
	return;
}

# Fire a signal within an object method
# - will return an error hash ptr if signal is not active or registered
sub tripfire_signal {
	my $self = shift;
	my (%pms) = @_;
	my $carp = 0;
	if(exists $pms{carp}) {
		$carp = $pms{carp};
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
	print "[WXPOEIO] tripfire: sigkey[$sigkey] val[$sigvalue]\n" if $self->{SIGNAL_LOOP_CARP};
	if( !exists $self->{SIGNAL_KEYS}->{$sigkey}) {
		# warn...a potential configuration error
		warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
		return undef;
	}
	
	if(exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_BLOCKED} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_BLOCKED}) {
		print "[WXPOEIO] tripfire: this signal[".$sigkey."] is blocked - inactive - ignoring signal\n" if $carp;
		if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SENDBACK_NOTICE_NO_REGISTRATION} and $self->{SIGNAL_KEY_HREF}->{$sigkey}->{SENDBACK_NOTICE_NO_REGISTRATION} ) {
			return {status=>-1,message=>'Signal is not registered/active'}
		}
		return undef;
	}

	if( exists $self->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
		# check signal key against FRAME_TO_FRAME channel
		if($self->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
			$self->{KERNEL_PTR}->post($alias, 'TO_WX', $sigkey, $sigvalue);
			return 1;
		}
	}
	print "[WXPOEIO] sending sigkey[$sigkey] to_poe\n" if $self->{SIGNAL_LOOP_CARP};
	if ( exists $self->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $self->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		my $signal = {};
		$signal->{$sigkey} = $sigvalue;
		$self->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP} = $signal;
	}
	$self->{KERNEL_PTR}->post($alias, '_MANAGE_TO_POE', $sigkey, $sigvalue);
	#$self->{KERNEL_PTR}->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
	
	return 1;
}

# Where the work is started...
sub _manage_to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	print "[_MANAGE_TO_POE] check signal sigkey[$sigkey] val[$sigvalue]\n";

	# Search for this signal!
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $sigkey } ) {

		# Test for signal latch
		#  latching discards follow same signal until the latch expires.
		#  follow on signal are assumed to be bad signals

		print "[_MANAGE_TO_POE] check latch sigkey[$sigkey] val[$sigvalue]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

		# Test for whether a latch has been specified for the signal call
		# if no latch, send for lock check
		if ( !exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} or !$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} ) {
			print "[_MANAGE_TO_POE] no latch on sigkey[$sigkey] sending to manage_locking\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
			$_[KERNEL]->yield('_MANAGE_LOCKING', $sigkey, $sigvalue);
			return 1;
		}
		
		# Latching is expected
		# Test for whether the signal call has been latched
		if ( !exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}  or !$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
			# no latch; set latch and continue to POE
			print "[_MANAGE_TO_POE] no latch is set on sigkey[$sigkey] ... latched now!\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 1;
			$_[OBJECT]->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigkey} = 1;
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 1;
			$_[KERNEL]->delay('_MANAGE_LATCHING' => 1, $sigkey, $sigvalue);
			# send to manage_locking to check for locking
			$_[KERNEL]->yield('_MANAGE_LOCKING', $sigkey, $sigvalue);
			return 1;
		}

		print "[_MANAGE_TO_POE] sigkey[$sigkey] is latched, discarding duplicate signal...nothing done!\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

	} else {
		# Ignore this signalkey
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Got this Signal_key: [$sigkey] -> Ignoring it because it is not registered";
		}
	}

	# All done!
	return 1;
}

# Where the work results are set...
sub _set_results_and_end {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue, $res_href ) = @_[ ARG0, ARG1, ARG2 ];

	my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
	$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
	$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
	$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = '_default_';
	if($res_href=~/HASH/i) {
		if(exists $res_href->{status}) {
			$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = $res_href->{status};
			delete $res_href->{status};
		}
		if(exists $res_href->{message}) {
			$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = $res_href->{message};
			delete $res_href->{message};
		}
		if(exists $res_href->{layout_obj_method}) {
			$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = $res_href->{layout_obj_method};
			delete $res_href->{layout_obj_method};
		}
	}
	undef $res_href;
	
	print "[WXPOEIO SET RESULTS] for signal [$sigkey][$key] status[".$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}."] mess[".$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE}."]\n";
	$_[KERNEL]->yield('END_SIGNAL', $sigkey, $sigvalue);
	return;
}

# Where the work is finished...
sub _end_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];
	print "[WXPOEIO] end of signal - send response [".$sigkey."] clear signal\n";

	# Search for this signal!
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $sigkey } ) {

		# clear all latch, locks and noise for signal
		$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);

#		my $channel = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};

#		$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
#		$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

#		if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
#			delete $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
#		}
		
#		if ( scalar keys %{ $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
#			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;
#		}
	} else {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Terminating an unregistered signal. Opps! [$sigkey]";
		}
	}

	if ( exists $_[OBJECT]->{WXPOEIO_LOG}->{ $sigkey } ) {
#		print "send signal to logger! [".$sigkey."]\n";
		$_[KERNEL]->yield('_TO_LOGGER', $sigkey, $sigvalue);
	}

	# signal sent to wxframe, close loop
	print "[WXPOEIO] send response to_wx [".$sigkey."]\n";
	$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
	return 1;
}

# Where the work is finished...
sub _update_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue, $res_href ) = @_[ ARG0, ARG1, ARG2 ];
	
	my $update = 1;
	print "[WXPOEIO UPDATE SIGNAL] update - send notice [".$sigkey."] update signal[$update]\n" if $_[OBJECT]->{UPDATING_CARP};

	# Search for this signal!
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $sigkey } ) {

		my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
		$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
		$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
#		$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = '_default_';
		if($res_href=~/HASH/i) {
			if(exists $res_href->{status}) {
				$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = $res_href->{status};
				delete $res_href->{status};
			}
			if(exists $res_href->{message}) {
				$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = $res_href->{message};
#print "[update signal] message [".$res_href->{message}."]\n";
				delete $res_href->{message};
			}
#			if(exists $res_href->{layout_obj_method}) {
#				$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD} = $res_href->{layout_obj_method};
#				delete $res_href->{layout_obj_method};
#			}
		}
		undef $res_href;

	} else {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Terminating an unregistered signal. Opps! [$sigkey]";
		}
	}
	
#
#	if ( exists $_[OBJECT]->{WXPOEIO_LOG}->{ $sigkey } ) {
#		print "send signal to logger! [".$sigkey."]\n";
#		$_[KERNEL]->yield('_TO_LOGGER', $sigkey, $sigvalue);
#	}

	# signal sent to wxframe, close loop
	print "[WXPOEIO UPDATE] send update[$update] notice to_wx [".$sigkey."]\n" if $_[OBJECT]->{UPDATING_CARP};
	$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue, $update);
	return 1;
}

# Where EVEN MORE work is done...
sub _toWx {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $self, $sigkey, $sigvalue, $update ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	if($self->{TOWX_CARP}) {
		print " send to WX - send response [".$sigkey."]";
		print " update[$update]" if defined $update;
		print "\n";
	}

	# Search through the registrations for this specific one
	foreach my $wxframe ( keys %{ $_[OBJECT]->{WXFRAMEIO} } ) {
		# Scan frame key for signal key
		print "[toWx] scan frame [$wxframe] for sigkey[$sigkey]\n" if $self->{TOWX_CARP};
		if ( exists $_[OBJECT]->{WXFRAMEIO}->{$wxframe}->{$sigkey} ) {
			# Scan for the proper evt_method!
			## first check for if this is an update notice
			if($update) {
				foreach my $evt_up ( keys %{ $_[OBJECT]->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_UPDATE} } ) {
					print "[toWx] found update method[$evt_up] for frame [$wxframe] for sigkey[$sigkey]\n" if $self->{TOWX_CARP};
					my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
					my $status = 0;
					my $message = 'null';
					my $layout_data_method = '_none_';
					if( exists $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}) {
						$status = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
						$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
					}
					if( exists $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE}) {
						$message = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
						$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
					}
					if(defined $_[OBJECT]->{WXFRAME_MGR}) {
						my $wxframe_obj = $_[OBJECT]->{WXFRAME_MGR}->frame_handle_by_key($wxframe);
						print "[toWx] using wfmgr for sending UPDATE to wxframe[$wxframe_obj] method[$evt_up] for sigkey[$sigkey] sigvalue[$sigvalue]\n" if $self->{TOWX_CARP};
						$wxframe_obj->$evt_up( $sigkey, $sigvalue, $status, $message, );
					}
					## else, fail silently...nothing is return to the wxframe
				}
				return 1;
			}
			foreach my $evt_meth ( keys %{ $_[OBJECT]->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_METHODS} } ) {

				print "[toWx] found method[$evt_meth] for frame [$wxframe] for sigkey[$sigkey]\n" if $self->{TOWX_CARP};

				my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
				my $status = 0;
				my $message = 'null';
				my $data_method = '_default_';
				if( exists $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}) {
					$status = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
					$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS} = 0;
				}
				if( exists $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE}) {
					$message = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
					$_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE} = '';
				}
				if(defined $_[OBJECT]->{WXFRAME_MGR}) {
					my $wxframe_obj = $_[OBJECT]->{WXFRAME_MGR}->frame_handle_by_key($wxframe);
					if( my $ref = eval { $wxframe_obj->can($evt_meth) } ) {
						$wxframe_obj->$evt_meth( $sigkey, $sigvalue, $status, $message, );
						print ".........method found[".$evt_meth."][$ref] in [$wxframe_obj]\n" if $self->{TOWX_CARP};
					} else {
						print ".........method NOT found[".$evt_meth."] in [$wxframe_obj]\n" if $self->{TOWX_CARP};
						next;
					}
					print "[toWx] using wfmgr for sending to wxframe[$wxframe_obj] method[$evt_meth] for sigkey[$sigkey] sigvalue[$sigvalue]\n" if $self->{TOWX_CARP};
					#my $wxframe_mgr = $_[OBJECT]->{WXFRAME_MGR};
					#$wxframe_mgr->$evt_meth( wxframe => $wxframe_obj, sigkey => $$sigkey, sigvalue => $sigvalue, status => $status, message => $message );
				} elsif ( exists $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$wxframe}->{WXFRAME_OBJ} ) {
					my $wxframe_obj = $_[OBJECT]->{WXFRAMEIO_WXSIGHANDLE}->{$wxframe}->{WXFRAME_OBJ};
					$wxframe_obj->$evt_meth( $sigkey, $sigvalue, $status, $message, );
				}
			}
		}
	}
	return 1;
}

# manage (count-out) the latching here
sub _manage_latching {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	## check if latch is still in timeout
	## if signal reachs timeout, loop ends
	## a long latch could block new signals to quick duration tasks

	my $states = $_[OBJECT]->{WXPOEIO_WAIT_SIGNAL_LATCH};
	my $count = 0;
	print "{WXPOEIO - MANAGE LATCH] manage the latch in-sigkey[$sigkey] ct[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]\n" if $_[OBJECT]->{SIGNAL_LATCH_CARP};
	foreach my $sigkey (keys %$states) {
		print " =[WXPOEIO - WAIT LATCH] for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]\n" if $_[OBJECT]->{SIGNAL_LATCH_CARP};
		if($states->{$sigkey}) {
			$count++;
			if(!$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
				$count--;
				$states->{$sigkey} = 0;
				print " == [WXPOEIO - WAIT LATCH] latch *done* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]\n" if $_[OBJECT]->{SIGNAL_LATCH_CARP};
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 0;
			}
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} + 1;
			if ( $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} > $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_TIMEOUT}) {
				$count--;
				$states->{$sigkey} = 0;
				print " == [WXPOEIO - WAIT LATCH] latch *count-out* for sigkey[$sigkey] state[".$states->{$sigkey}."] count[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS}."]\n" if $_[OBJECT]->{SIGNAL_LATCH_CARP};
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 0;
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

# Where the work is finally send to POE...
sub _to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	# Now, loop over each possible poe session (poe alias), 
	foreach my $TSession ( keys %{ $_[OBJECT]->{WXPOEIO}->{$sigkey} } ) {
		print "[TO_POE] found session alias [$TSession] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
		my $PSession = undef;
		my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
		if($TSession=~/_MAIN_WXSESSION_ALIAS_/i) {
			$PSession = $_[OBJECT]->{MAIN_WXSERVER_ALIAS};
			my $evt_meth = $_[OBJECT]->{WXPOEIO}->{$sigkey}->{$TSession}->{EVT_METHOD_POE};
			print "[TO_POE] use main session [$TSession] at alias [$PSession] meth[$evt_meth] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

			$_[KERNEL]->post(	$PSession,
								$evt_meth,
								$sigkey,
								$sigvalue,
					);
			return 1;
		}
		# Find out if this session exists
		print "[TO_POE] TSession[$TSession] not _MAIN..._\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
		if ( ! $_[KERNEL]->ID_id_to_session( $TSession ) ) {
			# rats...:)
			if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
				print "[TO_POE] initial TSession[$TSession] does not have a session ID\n";
#				warn "TSession ID $TSession does not exist";
			}
			print "[TO_POE] use main session [$TSession] at alias [$PSession] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
			if(defined $_[KERNEL]->alias_resolve($TSession)) {
				my $ts = $_[KERNEL]->alias_resolve($TSession);
#				warn "TSession ID is [".$ts."]";
				$PSession = $_[KERNEL]->ID_session_to_id( $ts );
				print "[TO_POE] using -ALIAS-Resolve- ts-alias[$ts] new PSession[$PSession] for signal [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
#				print "[TO_POE] using -ALIAS-Resolve- ts-alias[$ts] new PSession[$PSession] meth[$evt_meth] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
#				warn "new TSession ID [$PSession] has been found";
			}
		} else {
			$PSession = $TSession;
		}

		# Send signal to event method
		my $evt_method = $_[OBJECT]->{WXPOEIO}->{$sigkey}->{$PSession}->{EVT_METHOD_POE};
		print "[TO_POE] session post, to alias[$PSession] meth[$evt_method] for signal [$sigkey] \n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

		$_[KERNEL]->post(	$PSession,
							$evt_method,
							$sigkey,
							$sigvalue,
				);
		return 1;

	}
	return 0;
}

# And send to POE LOGGER...
sub _to_logger {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];
	print "To logger - send to main...maybe [".$sigkey."]\n";

	my $res_href = {};
	$res_href->{STATUS} = 0;
	$res_href->{MESSAGE} = 'No results';
	my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
	if(exists $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS}) {
		$res_href->{STATUS} = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{STATUS};
		$res_href->{MESSAGE} = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{MESSAGE};
		$res_href->{LAYOUT_OBJ_METHOD} = $_[OBJECT]->{WXFRAMEIO_RESULTS}->{$key}->{LAYOUT_OBJ_METHOD};
	}

	# Now, loop over each possible poe session (poe alias), 
	foreach my $TSession ( keys %{ $_[OBJECT]->{WXPOEIO_LOG}->{$sigkey} } ) {
		print "[TO_LOGGER] found session alias [$TSession] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};
		my $PSession = undef;
		my $key = $sigkey . "_" . $sigvalue; ## avoiding potential '0' keys
		if($TSession=~/_MAIN_WXSESSION_ALIAS_/i) {
			$PSession = $_[OBJECT]->{MAIN_WXSERVER_ALIAS};
			my $evt_meth = $_[OBJECT]->{WXPOEIO_LOG}->{$sigkey}->{$TSession}->{EVT_METHOD_LOG};
			print "[TO_LOGGER] use main session [$TSession] at alias [$PSession] meth[$evt_meth] for signal [$sigkey] [".$_[OBJECT]->{MAIN_WXSERVER_ALIAS}."]\n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

			$_[KERNEL]->post(	$PSession,
								$evt_meth,
								$sigkey,
								$sigvalue,
								$res_href,
					);
			return 1;
		}
		# Find out if this session exists
		if ( ! $_[KERNEL]->ID_id_to_session( $TSession ) ) {
			# rats...:)
			if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
				warn "TSession ID $TSession does not exist";
			}
			print "[TO_POE] TSession[$TSession] does not have a session ID\n";
			if(defined $_[KERNEL]->alias_resolve($TSession)) {
				my $ts = $_[KERNEL]->alias_resolve($TSession);
#				warn "TSession ID is [".$ts."]";
				$PSession = $_[KERNEL]->ID_session_to_id( $ts );
#				warn "new TSession ID [$PSession] has been found";
			}
		} else {
			$PSession = $TSession;
		}

		# Send signal to event method
		my $evt_method = $_[OBJECT]->{WXPOEIO_LOG}->{$sigkey}->{$PSession}->{EVT_METHOD_LOG};
		print "[TO_LOGGER] session post, to alias[$PSession] meth[$evt_method] for signal [$sigkey] \n" if $_[OBJECT]->{SIGNAL_LOOP_CARP};

		$_[KERNEL]->post(	$PSession,
							$evt_method,
							$sigkey,
							$sigvalue,
							$res_href,
				);
		return 1;

	}
	return 0;
}

# Manage channel locking
sub _manage_locking {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	# if signal requires a channel lock, check on lock and channel use (noise)
	my $channel = 'MAIN'; # default
	if ( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}  and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}) {
		$channel = $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL};
	}
	if(!$channel) {
		# rats...something broke
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Darn! Looks like the channel value is null. Please fix!";
		}
		return undef;
	}
	
	## check if channel locking is required
	print "[_MANAGE_LOCKING] using channel [$channel] for signal [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	if ( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK}  and $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		## locking is required, check for lock...and channel noise 
		print "[_MANAGE_LOCKING] lock required for channel[$channel] signal [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
		if ( !exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}  or !$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}) {
			## channel is unlocked, lock channel and send to POE
			print "[_MANAGE_LOCKING] NEW lock state for channel[$channel] signal [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
			if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}  and $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}) {
				print "[_MANAGE_LOCKING] channel [$channel] is in use, but no conflict" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
			} else {
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 1;
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} = 1;
			}
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS} = 0;
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 1;
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{LOCK_SIGNAL} = {$sigkey => $sigvalue};
			$_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_LOCK}->{$channel} = 1;
#			$_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel}->{$sigkey} = 1;
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 1;
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT} = $_[OBJECT]->{LOCK_TIMEOUT_DEFAULT};
			if(exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_TIMEOUT}) {
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT} = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_TIMEOUT};
			}
			print "[_MANAGE_LOCKING] lock end count [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}."] for channel[$channel] signal [$sigkey].\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
			$_[KERNEL]->yield('_TO_POE', $sigkey, $sigvalue);
			if($_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}) {
				## an endcount of 0 means that the lock does not timeout.
				$_[KERNEL]->delay('_WAIT_ON_LOCK_TIMEOUT' => 1, $sigkey, $sigvalue);
			}
			return 1;
		}
		if( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{LOCK_RETRY_TIME} ) {
			if( $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK_RETRY_TIME} ) {
				if ( !exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS}) {
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS} = 0;
				}
				$_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel}->{$sigkey} = 1;
				print "[_MANAGE_LOCKING] lock state [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}."] for channel[$channel] signal [$sigkey]...validate signal for reset\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
				if ( !exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED}  or !$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED}) {
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_BLOCKED} = 1;
				}
				$_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK}->{$sigkey} = 1;
	#			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{RETRY_ATTEMPTS} = 0;
	#			my $signal = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_HOLD_TMP};
				my $signal = $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{LOCK_SIGNAL}; # = {$sigkey => $sigvalue};
				foreach my $sigkey2 (keys %$signal) {
					my $sigvalue2 = $signal->{$sigkey2};
					print "[_MANAGE_LOCKING] comparing signal; this signal[$sigkey]:tmp_hold_sig[$sigkey2] sigval[$sigvalue2]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
					if($sigkey2=~/^$sigkey$/) {
						if($sigvalue2=~/^$sigvalue$/) {
							## drop this signal
							## do not use repeated signals to avoid creating race conditions or secondary errors
							print "== [_MANAGE_LOCKING] dropping this signal[$sigkey]:[$sigvalue]...cannot reset same signal\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
							$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);
							return 0;
						}
					}
				}
				my $signal_reload = {$sigkey => $sigvalue};
				print "[_MANAGE_LOCKING] reloading this signal[$sigkey] into the siqnal queue\n" if $_[OBJECT]->{SIGNAL_LATCH_CARP};
	#			my $sq = $_[OBJECT]->{WXPOEIO_QUEUE};
				my $sq = $_[OBJECT]->{WXPOEIO_QUEUE_TMP_HOLD};
				push @$sq, $signal_reload;
				$_[KERNEL]->delay('_WAIT_POE_LOCK' => 1, $sigkey, $sigvalue, $channel);
				return 1;
			} elsif( $_[OBJECT]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK_RETRY_TIME} == 0 ) {
				# LOCK_RETRY_TIME set to [0]...indefinite lock!
				print "[_MANAGE_LOCKING] indefinite lock state [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}."] for channel[$channel] - dropping signal [$sigkey]...swap signal for reset\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
				return 1;
			}
		}
	}
	$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 1;
	$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} = 1;
	print "[_MANAGE_LOCKING] using WXPOEIO_CHANNELS channel [$channel] for signal [$sigkey] [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	$_[KERNEL]->yield('_TO_POE', $sigkey, $sigvalue);

	return 1;
}

# Clear signal settings
sub _clear_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];
	print "[_CLEAR_SIGNAL] clear this signal [".$sigkey."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
	# Search for this signal!
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $sigkey } ) {

		my $channel = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};
		if( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} and defined $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} ) {
			if( $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE} != $sigvalue) {
				## this signal set is not able to terminate the lock on this signal/channel
				warn "[WXPOEIO - CLEAR SIGNAL] this sigkey[$sigkey] and sigval[$sigvalue]!=[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{SIGNAL_KILL_SIGVALUE}."] - cannot remove lock on channel[$channel].\n";
				return 1;
			}
		}
	
		# clear all latch, locks and noise for signal
		print " =[_CLEAR_SIGNAL] filtering channel [".$channel."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};

		$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
		$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

		if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} and $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} ) {
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
		}

		if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
			delete $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
		}
		print " =[_CLEAR_SIGNAL] clear signal latch, clear lock, clear wait, clear signal noise" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
		
		if ( scalar keys %{ $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;
			print ", clear channel noise" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
		}
		print " [".$channel."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};

		if ( exists $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel} and scalar(keys $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel})) {
			my $states = $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel};
			foreach my $sig (keys %$states) {
				if($states->{$sig}) {
					$states->{$sig} = 0;
#					$_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK}->{$sig} = 0;
					print " =[_CLEAR_SIGNAL] clear block for sig[$sig] on channel[$channel]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig}->{WAIT_BLOCKED} = 0;
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig}->{RETRY_ATTEMPTS} = 0;
				}
			}
		}
		
	} else {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Cannot clear an unregistered signal. Opps! [$sigkey]";
		}
	}
	return 1;
}

# Timeout a signal call to a locked channel
sub _wait_poe_lock {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue, $channel ) = @_[ ARG0, ARG1, ARG2 ];

	## must check for whether the lock has been cleared during the delay to poe_lock
	## if the lock is clear, re-submit signal and trigger signals
	## if the wait time has expired, let signal die
	my $states = $_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK};
	my $count = 0;
	print "[WXPOEIO LOCK_WAIT-ON] count wait for lock release [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	foreach my $sig_key (keys %$states) {
		print " =[WXPOEIO LOCK_WAIT LOOP] for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
		if($states->{$sig_key}) {
			$count++;
			if(	!$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}) {
				$count++;
				$states->{$sig_key} = 0;
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} = 0;
				print " =[WXPOEIO LOCK LOOP] lock completed for sigkey[$sigkey][$sig_key] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}."] not_done[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
			}
			$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}++;
			if($_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} > $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{LOCK_RETRY_TIME}) {
				$count--;
				$states->{$sig_key} = 0;
				print " =[WXPOEIO WAIT_POE_LOCK LOOP] lock counted out for sigkey[$sigkey][$sig_key] val[$sigvalue] channel[".$channel."] active[".$states->{$sig_key}."] count[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS}."] not_done[".$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{WAIT_BLOCKED} = 0;
#				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig_key}->{RETRY_ATTEMPTS} = 0;
#				$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);
			}
		}
	}
	if($count < 1) {
		return;
	}
	my $sq_tmp = $_[OBJECT]->{WXPOEIO_QUEUE_TMP_HOLD};
	my $sq = $_[OBJECT]->{WXPOEIO_QUEUE};
	print "[WXPOEIO LOCK_WAIT-ON] sigkey for lock release[$sigkey] back onto sigqueue [" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	while(scalar(@$sq_tmp)) {
		my $signal = shift @$sq_tmp;
		push @$sq, $signal;
		## must terminate any latches...bitches, they are...
		foreach my $sigk (keys %$signal) {
			if(exists $_[OBJECT]->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk} and $_[OBJECT]->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk}) {
				$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigk}->{IS_LATCHED} = 0;
				$_[OBJECT]->{WXPOEIO_WAIT_SIGNAL_LATCH}->{$sigk} = 0;
			}
			if($_[OBJECT]->{SIGNAL_LOCK_CARP}) {
				print $sigk . "," ;
			}
		}
	}
	print "] - trigger signals\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	$_[KERNEL]->yield('TRIGGER_SIGNALS');
	return 1;
}

# timeout a locked channel here
sub _wait_on_lock {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	my $states = $_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_LOCK};
	my $count = 0;
	print "[WXPOEIO CHANNEL LOCK] sigkey lock release [$sigkey]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	foreach my $channel (keys %$states) {
		print " =[WXPOEIO LOCK LOOP] for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
		if($states->{$channel}) {
			$count++;
			if(!$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}) {
				$count--;
				$states->{$channel} = 0;
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
				print " =[WXPOEIO LOCK LOOP] lock completed for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
			}
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}++;
			if($_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} > $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_ENDCOUNT}) {
				$count--;
				$states->{$channel} = 0;
				print " =[WXPOEIO LOCK LOOP] lock counted out for sigkey[$sigkey] val[$sigvalue] channel[".$channel."] active[".$states->{$channel}."] count[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."] not_done[".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK}."]\n";
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
				$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT} = 0;
				$_[KERNEL]->yield('_CLEAR_SIGNAL', $sigkey, $sigvalue);
			}
		}
	}
	if($count < 1) {
		return;
	}
	## continue until count goes to zero!
	my $channel = 'MAIN'; # default
	if ( exists $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL}  and $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL}) {
		$channel = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};
	}
	print " =[WXPOEIO LOCK LOOP] wait on sigkey[$sigkey] lock - lock count [".$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK_COUNT}."]\n" if $_[OBJECT]->{SIGNAL_LOCK_CARP};
	$_[KERNEL]->delay('_WAIT_ON_LOCK_TIMEOUT' => 1, $sigkey, $sigvalue);
	return 1;
}

# Kill signal settings - use to clear a DNS start/stop signal 
sub _kill_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];
	print "[_CLEAR_SIGNAL] clear this signal [".$sigkey."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
	# Search for this signal!
	if ( exists $_[OBJECT]->{WXPOEIO}->{ $sigkey } ) {

		# clear all latch, locks and noise for signal
		my $channel = $_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};
		print " =[_CLEAR_SIGNAL] filtering channel [".$channel."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};

		$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
		$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

		if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} and $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} ) {
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{WAIT_LOCK} = 0;
		}

		if ( exists $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
			delete $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
		}
		print " =[_CLEAR_SIGNAL] clear signal latch, clear lock, clear wait, clear signal noise" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
		
		if ( scalar keys %{ $_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
			$_[OBJECT]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;
			print ", clear channel noise" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
		}
		print " [".$channel."]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};

		if ( exists $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel} and scalar(keys $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel})) {
			my $states = $_[OBJECT]->{WXPOEIO_WAIT_SIGNALS_TO_UNLOCK}->{$channel};
			foreach my $sig (keys %$states) {
				if($states->{$sig}) {
					$states->{$sig} = 0;
#					$_[OBJECT]->{WXPOEIO_WAIT_CHANNEL_TO_UNLOCK}->{$sig} = 0;
					print " =[_CLEAR_SIGNAL] clear block for sig[$sig] on channel[$channel]\n" if $_[OBJECT]->{CLEAR_SIGNAL_CARP};
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig}->{WAIT_BLOCKED} = 0;
					$_[OBJECT]->{SIGNAL_KEY_HREF}->{$sig}->{RETRY_ATTEMPTS} = 0;
				}
			}
		}
		
	} else {
		if ( $_[OBJECT]->{SIGNAL_LOOP_CARP} ) {
			warn "Cannot clear an unregistered signal. Opps! [$sigkey]";
		}
	}
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

sub import_frame_mgr_ptr {
	my $ptr_var = $_[ ARG0 ];
	if(!exists $_[OBJECT]->{WXFRAME_MGR}) {
		$_[OBJECT]->{WXFRAME_MGR} = $ptr_var;
	}
	$_[OBJECT]->{WXFRAME_MGR} = $ptr_var;
	return 1;
}

# End of module
no Moose;
1;
