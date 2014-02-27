# Declare the package
package POE::Component::WxPoeIO;
use strict;
use warnings;

# Initialize our version
our $VERSION = '0.001001';

# Import what we need from the POE namespace
use POE;

# Other miscellaneous modules
use Carp;

# Set some constants
BEGIN {
	# Debug fun!
	if ( ! defined &DEBUG ) {
		eval "sub DEBUG () { 0 }";
	}
}

# Setup IO process
sub new {
	# Get the OOP's type
	my $type = shift;

	# Sanity checking
	if ( @_ & 1 ) {
		croak( 'POE::Component::WxPoeIO->new needs even number of options' );
	}

	# The options hash
	my %opt = @_;

	# Our own options
	my ( $ALIAS, $SIGNAL_KEYS, $QUEUE );

	# Get the session alias
	if ( exists $opt{ALIAS} ) {
		$ALIAS = $opt{ALIAS};
		delete $opt{ALIAS};
	} else {
		# Debugging info...
		if ( DEBUG ) {
			warn 'Using default ALIAS = WxPoeIO';
		}

		# Set the default
		$ALIAS = 'WxPoeIO';
	}
	if ( exists $opt{SIGNAL_QUEUE} ) {
		$QUEUE = $opt{SIGNAL_QUEUE};
		delete $opt{SIGNAL_QUEUE};
	} else {
		# Debugging info...
		if ( DEBUG ) {
			warn 'No signal queue imported. Generating an array pointer.\n\tExport using EXPORT_SIG_QUEUE_PTR';
		}
		# Set an empty array pointer
		$QUEUE = [];
	}
	
	# Get the signal keys defined by root script
	# These are held constant between Poe session and Wx frames
	if ( exists $opt{'SIGNAL_KEYS'} ) {
		$SIGNAL_KEYS = $opt{'SIGNAL_KEYS'};
		delete $opt{'SIGNAL_KEYS'};

		# Check if it is defined
		if ( !$SIGNAL_KEYS or $SIGNAL_KEYS!~/HASH/i ) {
			# reset $SIGNAL_KEYS to be only undef
			$SIGNAL_KEYS = undef;
		}
	} else {
		# Set signals to undefined because no key constants have been sent
		$SIGNAL_KEYS = undef;
	}

	# Anything left over is unrecognized
	if ( DEBUG ) {
		if ( keys %opt > 0 ) {
			croak 'Unrecognized options were present in POE::Component::WxPoeIO->new -> ' . join( ', ', keys %opt );
		}
	}

	# Create a new session for ourself
	POE::Session->create(
		# Our subroutines
		'inline_states'	=>	{
			# Maintenance events
			'_start'	=>	\&StartIO,
			'_stop'		=>	sub {},

			# Config a signal [key] push for use...this is not the same as registing for a signal broadcast
			'CONFIG_SIGNAL'	=>	\&Config_signal,

			# Register an IO session
			'REGISTER_SESSION'	=>	\&Register_session,

			# Unregister an IO session
			'UNREGISTER_SESSION'	=>	\&UnRegister_session,

			# Register an IO frame
			'REGISTER_FRAME'	=>	\&Register_frame,

			# Unregister an IO frame
			'UNREGISTER_FRAME'	=>	\&UnRegister_frame,

			# Register a wxframe to wxframe IO on FRAME_TO_FRAME channel
			'REGISTER_FRAME_TO_FRAME'	=>	\&Register_frame_to_frame,

			# Trigger signals
			'TRIGGER_SIGNALS'		=>	\&trigger_signals,

			# Terminate signal and clean up state
			'END_SIGNAL'		=>	\&end_signal,

			# SIGNAL SOMETHING to POE!
			'TO_POE'		=>	\&toPoe,
			# SIGNAL SOMETHING to WxFrame!
			'TO_WX'			=>	\&toWx,

			# Manage POE SIGNAL
			'_MANAGE_LATCHING'	=>	\&_manage_latching,

			# Manage POE SIGNAL
			'_MANAGE_TO_POE'	=>	\&_manage_to_poe,

			# Wait loop for latched POE SIGNAL
			'_WAIT_ON_LATCH'	=>	\&_wait_on_latch,

			# Wait loop for locked POE SIGNAL
			'_WAIT_TO_POE'	=>	\&_wait_to_poe,

			# export method to obtain the pointer to the signal queue
			'EXPORT_SIG_QUEUE_PTR' => \&export_queue_ptr,
			
			# We are done!
			'SHUTDOWN'	=>	\&StopIO,
		},

		# Set up the heap for ourself
		'heap'		=>	{
			'ALIAS'		=>	$ALIAS,

			# The session registation table
			'WXPOEIO'	=>	{},

			# SIGNAL_KEYS
			'SIGNAL_KEYS'	=>	$SIGNAL_KEYS,

			# The frame registration table
			'WXFRAMEIO'	=>	{},

			# The channel registration table
			'WXPOEIO_CHANNELS'	=>	{'MAIN'=>undef},

			# The channel registration table
			'WXPOEIO_QUEUE'	=>	$QUEUE,
		},
	) or die 'Unable to create a new session!';

	# Return success
	return 1;
}

# Configure a new io signal for latching and locking
sub Config_signal {
	# Get the arguments
	my $args = $_[ ARG0 ];

	my %loc_args = ('SIGNAL_CHANNEL'=>'MAIN','LATCH'=>1,'TIMEOUT'=>0,'LOCK'=>0,'RETRIES'=>100);

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}

	if ( ! defined $args->{SIGNAL_CHANNEL} ) {
		if ( DEBUG ) {
			warn "Did not get a signal channel for signal: ".$args->{SIGNAL_KEY}." - using default [MAIN] channel";
		}
	}
	if ( exists $args->{SIGNAL_CHANNEL} and $args->{SIGNAL_CHANNEL} ) {
		$loc_args{SIGNAL_CHANNEL} = $args->{SIGNAL_CHANNEL};
	}
	if ( exists $args->{LATCH} and !$args->{LATCH} ) {
		$loc_args{LATCH} = 0;
	}
	if ( exists $args->{TIMEOUT} and $args->{TIMEOUT} ) {
		$loc_args{TIMEOUT} = $args->{TIMEOUT};
	}
	if ( exists $args->{LOCK} and $args->{LOCK} ) {
		$loc_args{LOCK} = 1;
	}
	if ( exists $args->{RETRIES} ) {
		$loc_args{RETRIES} = $args->{RETRIES};
		# Force falsy state to be an integer 0
		if(!$loc_args{RETRIES}) {
			$loc_args{RETRIES} = 0;
		}
	}

	if ( !exists $_[HEAP]->{SIGNAL_KEYS}->{ $args->{SIGNAL_KEY} } ) {
		warn 'Setting undefined SIGNAL KEY ['.$args->{SIGNAL_KEY}.']. Possible void context.';
		if ( DEBUG ) {
			warn 'Signal key ['.$args->{SIGNAL_KEY}.'] not properly initialized';
		}
	}
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = $loc_args{SIGNAL_CHANNEL};
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = $loc_args{LATCH};
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LOCK} = $loc_args{LOCK};
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{TIMEOUT} = $loc_args{TIMEOUT};
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{RETRIES} = $loc_args{RETRIES};
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{IS_LATCHED} = 0;
	if ( !exists $_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }  or !$_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } ) {
		$_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} } = {};
	}
	$_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_LOCKED} = 0;
	$_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{IS_NOISY} = 0;
	$_[HEAP]->{WXPOEIO_CHANNELS}->{ $loc_args{SIGNAL_CHANNEL} }->{NOISE} = undef;

	# Config complete!
	return 1;
}

# Register a session to watch/wait for io signal
sub Register_session {
	# Get the arguments
	my $args = $_[ ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}

	if ( ! defined $args->{SESSION} ) {
		if ( DEBUG ) {
			warn "Did not get a TargetSession for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	} else {
		# Convert actual POE::Session objects to their ID
		if ( UNIVERSAL::isa( $args->{SESSION}, 'POE::Session') ) {
			$args->{SESSION} = $args->{SESSION}->ID;
		}
	}
	if ( ! defined $args->{EVT_METHOD} ) {
		if ( DEBUG ) {
			warn "Did not get an EvtMethod for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
		}
		return undef;
	}

#	# register within the WXPOEIO hash structure
	if ( ! exists $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } ) {
		$_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } = {};
	}

	if ( ! exists $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } ) {
			$_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } = {};
	}

	# Finally store the event method in the signal key hash
	if ( exists $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{ $args->{EVT_METHOD} } ) {
		# Duplicate record...
		if ( DEBUG ) {
			warn "Tried to register a duplicate! -> LogName: ".$args->{SIGNAL_KEY}." -> Target Session: ".$args->{SESSION}." -> Event: ".$args->{EVT_METHOD};
		}
	} else {
		$_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{ $args->{EVT_METHOD} } = 1;
	}

	# All registered!
	return 1;
}

# Delete a watcher session
sub UnRegister_session {
	# Get the arguments
	my $args = $_[ ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	if ( ! defined $args->{SESSION} ) {
		if ( DEBUG ) {
			warn "Did not get a TargetSession for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	} else {
		# Convert actual POE::Session objects to their ID
		if ( UNIVERSAL::isa( $args->{SESSION}, 'POE::Session') ) {
			$args->{SESSION} = $args->{SESSION}->ID;
		}
	}

	if ( ! defined $args->{EVT_METHOD} ) {
		if ( DEBUG ) {
			warn "Did not get an EvtMethod for SignalKey: ".$args->{SIGNAL_KEY}." and Target Session: ".$args->{SESSION};
		}
		return undef;
	}

	# Search through the registrations for this specific one
	if ( exists $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} } ) {
		# Scan it for targetsession
		if ( exists $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } ) {
			# Scan for the proper event!
			foreach my $evt_meth ( keys %{ $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } } ) {
				if ( $evt_meth eq $args->{EVT_METHOD} ) {
					# Found a match, delete it!
					delete $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} }->{ $evt_meth };
					if ( scalar keys %{ $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} } } == 0 ) {
						delete $_[HEAP]->{WXPOEIO}->{ $args->{SIGNAL_KEY} }->{ $args->{SESSION} };
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

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( DEBUG ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}," and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{WX_METHOD} ) {
		if ( DEBUG ) {
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
		if ( DEBUG ) {
			warn "Did not get a WxFrame Object for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	}


	# register within the WXPOEIO hash structure
	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame} ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame} = {};
	}

	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
	}

	# Finally store the wx method in the signal key method hash
	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
	}
	$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{WX_METHOD} } = 1;

	# set USE_WXFRAME_MGR to falsy as default
	$_[HEAP]->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
	if($wxframe_mgr) {
		$_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
	} else {
		$_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
	}

	# All registered!
	return 1;
}

# Delete a watcher frame
sub UnRegister_frame {
	# Get the arguments
	my $args = $_[ ARG0 ];

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( DEBUG ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{WX_METHOD} ) {
		if ( DEBUG ) {
			warn "Did not get an WxMethod for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}

	# Search through the registrations for this specific one
	if ( exists $_[HEAP]->{WXFRAMEIO}->{$frame} ) {
		# Scan it for signal key
		if ( exists $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
			# Scan for the proper event!
			foreach my $evt_meth ( keys %{ $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} } ) {
				if ( $evt_meth eq $args->{WX_METHOD} ) {
					# Found a match, delete it!
					delete $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $evt_meth };
					if ( scalar keys %{ $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} } == 0 ) {
						delete $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS};
						if ( scalar keys %{ $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } } == 0 ) {
							delete $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} };
							if ( scalar keys %{ $_[HEAP]->{WXFRAMEIO}->{$frame} } == 0 ) {
								delete $_[HEAP]->{WXFRAMEIO}->{$frame};
								if( exists $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} ) {
									delete $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR};
								}
								if( exists $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} ) {
									delete $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ};
								}
								if ( scalar keys %{ $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame} } == 0 ) {
									delete $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame};
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

	# Validation - silently ignore errors
	if ( ! defined $args->{SIGNAL_KEY} ) {
		if ( DEBUG ) {
			warn 'Did not get any arguments';
		}
		return undef;
	}
	my $frame = 'DEFAULT';
	if ( exists $args->{WXFRAME_IDENT} ) {
		$frame = $args->{WXFRAME_IDENT};
	}
	if ( ! defined $frame ) {
		if ( DEBUG ) {
			warn "Did not get a valid frame name for SignalKey: ".$args->{SIGNAL_KEY}." and wxFrame Object: ".$args->{WXFRAME_OBJ};
		}
		return undef;
	}
	if ( ! defined $args->{WX_METHOD} ) {
		if ( DEBUG ) {
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
		if ( DEBUG ) {
			warn "Did not get a WxFrame Object for SignalKey: ".$args->{SIGNAL_KEY};
		}
		return undef;
	}

	# register within the WXPOEIO hash structure
	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame} ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame} = {};
	}

	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} } = {};
	}

	# Finally store the wx method in the signal key method hash
	if ( ! exists $_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} ) {
		$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS} = {};
	}
	$_[HEAP]->{WXFRAMEIO}->{$frame}->{ $args->{SIGNAL_KEY} }->{WX_METHODS}->{ $args->{WX_METHOD} } = 1;

	# set USE_WXFRAME_MGR to falsy as default
	$_[HEAP]->{WXFRAMEIO}->{$frame}->{USE_WXFRAME_MGR} = 0; 
	if($wxframe_mgr) {
		$_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{USE_WXFRAME_MGR} = 1; 
	} else {
		$_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$frame}->{WXFRAME_OBJ} = $args->{WXFRAME_OBJ};
	}

	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{WXPOEIO_CHANNEL} = 'FRAME_TO_FRAME';
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $args->{SIGNAL_KEY} }->{LATCH} = 0;
	if ( !exists $_[HEAP]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} ) {
		$_[HEAP]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME} = {};
	}

	# All registered!
	return 1;
}

# Where the work is queued...
sub trigger_signals {

	if ( exists $_[HEAP]->{WXPOEIO_QUEUE} ) {
		my $sq = $_[HEAP]->{WXPOEIO_QUEUE};
		if($sq!~/ARRAY/i) {
			if ( DEBUG ) {
				warn "The siqnal queue pointer is corrupt: [$sq]. Will not trigger signals";
			}
			return undef;
		}
		while( scalar(@$sq) ) {
			my $signal = shift @$sq;

			if($signal!~/HASH/i) {
				if ( DEBUG ) {
					warn "The siqnal hash pointer is corrupt: [$signal]. Cannot determine signal key and value";
				}
				next;
			}
			foreach my $sigkey (keys %$signal) {
				my $sigvalue = $signal->{$sigkey};
				if( !exists $_[HEAP]->{SIGNAL_KEYS}->{$sigkey}) {
					# warn...a potential configuration error
					warn "No SIGNAL_KEY for [$sigkey] in SIGNAL_KEY hash! Check signal key settings";
					next;
				}
				if( exists $_[HEAP]->{WXPOEIO_CHANNELS}->{FRAME_TO_FRAME}) {
					# check signal key against FRAME_TO_FRAME channel
					if($_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL} eq 'FRAME_TO_FRAME') {
						$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
						next;
					}
				}
				$_[KERNEL]->yield('TO_POE', $sigkey, $sigvalue);
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
	
# Where the work is done...
sub toPoe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	# Search for this signal!
	if ( exists $_[HEAP]->{WXPOEIO}->{ $sigkey } ) {

		# Test for signal latch
		# (latching restricts follow on signal calls until task has been completed)

		# Test for whether a latch has been specified for the signal call
		if ( !exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} or !$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH} ) {
			$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
			return 1;
		}
		
		# Latching is expected
		# Test for whether the signal call has been latched
		if ( !exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}  or !$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
			# no latch; set latch and continue to POE
			$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 1;
			$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
			return 1;
		}

		$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_LATCH} = 1;
		$_[KERNEL]->yield('_WAIT_ON_LATCH', $sigkey, $sigvalue);

	} else {
		# Ignore this signalkey
		if ( DEBUG ) {
			warn "Got this Signal_key: [$sigkey] -> Ignoring it because it is not registered";
		}
	}

	# All done!
	return 1;
}

# Where the work is finished...
sub end_signal {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue, $_wfmgr ) = @_[ ARG0, ARG1, ARG2 ];

	# Search for this signal!
	if ( exists $_[HEAP]->{WXPOEIO}->{ $sigkey } ) {

		# clear all latch, locks and noise for signal
		my $channel = $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WXPOEIO_CHANNEL};

		$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED} = 0;
		$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 0;

		if ( exists $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
			delete $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
		}
		
		if ( scalar keys %{ $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
			$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;
		}
	} else {
		if ( DEBUG ) {
			warn "Terminating an unregistered signal. Opps! [$sigkey]";
		}
	}
	
	if( defined $_wfmgr) {
		$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue, $_wfmgr);
	} else {
		$_[KERNEL]->yield('TO_WX', $sigkey, $sigvalue);
	}
	# signal set to wxframe, close loop
	return 1;
}

# Where EVEN MORE work is done...
sub toWx {
	# ARG0 = signal_key, ARG1 = signal_value, [Optional, ARG2 = _wxframe_manager]
	my( $sigkey, $sigvalue, $_wfmgr ) = @_[ ARG0, ARG1, ARG2 ];

	# Search through the registrations for this specific one
	foreach my $wxframe ( keys %{ $_[HEAP]->{WXFRAMEIO} } ) {
		# Scan frame key for signal key
		if ( exists $_[HEAP]->{WXFRAMEIO}->{$wxframe}->{$sigkey} ) {
			# Scan for the proper evt_method!
			foreach my $evt_meth ( keys %{ $_[HEAP]->{WXFRAMEIO}->{$wxframe}->{$sigkey}->{WX_METHODS} } ) {

				if ( exists $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$wxframe}->{USE_WXFRAME_MGR} ) {
					$_wfmgr->$evt_meth( $sigkey,$sigvalue );
					return 1;
				}
				if ( exists $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$wxframe}->{WXFRAME_OBJ} ) {
					my $wxframe_obj = $_[HEAP]->{WXFRAMEIO_WXSIGHANDLE}->{$wxframe}->{WXFRAME_OBJ};
					$wxframe_obj->$evt_meth( $sigkey,$sigvalue );
#					return 1;
				}
				## else, fail silently...nothing is return to the wxframe
			}
		}
	}
	return 1;
}

# manage the latching here
sub _manage_latching {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}  and $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{IS_LATCHED}) {
		my $latches = 0;
		my $timeout = 0;
		if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} ) {
			$latches = $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS};
		}
		if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{TIMEOUT} ) {
			$timeout = $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{TIMEOUT};
		}
		if( $latches > $timeout ) {
			# reset latch state and continue to Poe
			$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_LATCH} = 0;
			$_[KERNEL]->yield('_WAIT_ON_LATCH', $sigkey, $sigvalue);
			return;
		}
		$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} + 1;
		$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_LATCH} = 1;
		$_[KERNEL]->yield('_WAIT_ON_LATCH', $sigkey, $sigvalue);
		return;
	}
	$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
	return;
}

# activate kernel call to the session here
sub _manage_to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	# if signal requires a channel lock, check on lock and channel use (noise)
	my $channel = 'MAIN'; # default
	if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}  and $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL}) {
		$channel = $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WXPOEIO_CHANNEL};
	}
	if(!$channel) {
		# rats...something broke
		if ( DEBUG ) {
			warn "Darn! Looks like the channel value is null. Please fix!";
		}
		return undef;
	}
	if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}  and $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{LOCK}) {
		my $lock = 0;
		if ( exists $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}  and $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED}) {
			$lock = 1;
		}
		if ( exists $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}  and $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY}) {
			$lock = 1;
		}
		if($lock) {
			if ( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRIES}  and $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRIES}) {
				if ( !exists $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS}) {
					$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS} = 0;
				}
				if( $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS} < $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRIES} ) {
					$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS} = $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS} + 1;
					$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WAIT_LOCK} = 1;
					$_[KERNEL]->delay('_WAIT_TO_POE' => 1, $sigkey, $sigvalue);
				}
				# retry unsuccessful, return falsy
				return 0;
			}
		} else {
			$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WAIT_LOCK} = 0;
			$_[KERNEL]->delay('_WAIT_TO_POE' => undef, $sigkey, $sigvalue);
			$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{RETRY_ATTEMPTS} = 0;
			$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_LOCKED} = 1;
#			return;
		}
	}
	$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 1;
	$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} = 1;

	my $valid_sessions = 0;
	# Now, loop over each targetsession, checking if it is valid
	foreach my $TargetSession ( keys %{ $_[HEAP]->{WXPOEIO}->{ $sigkey } } ) {
		# Find out if this session exists
		my $PSession = undef;
		if ( ! $_[KERNEL]->ID_id_to_session( $TargetSession ) ) {
			# rats...:)
			if ( DEBUG ) {
				warn "TargetSession ID $TargetSession does not exist";
			}
			# but also test for an alias session name
			if(defined $_[KERNEL]->alias_resolve($TargetSession)) {
				my $ts = $_[KERNEL]->alias_resolve($TargetSession);
				$PSession = $_[KERNEL]->ID_session_to_id( $ts );
				if ( DEBUG ) {
					warn "Alias TargetSession ID [$PSession] has been found";
				}
			}
		} else {
			$PSession = $TargetSession;
		}
		# Find event methods to dispatch
		foreach my $evt_meth ( keys %{ $_[HEAP]->{WXPOEIO}->{ $sigkey }->{ $TargetSession } } ) {
			# We call event methods with 2 arguments
			# ARG0 -> SIGNAL_KEY
			# ARG1 -> SIGNAL_VALUE (message)
			$_[KERNEL]->post(	$PSession,
								$evt_meth,
								$sigkey,
								$sigvalue,
					);
			$valid_sessions++;
		}
	}
	if($valid_sessions) {
		# Return success
		return 1;
	}

	# no signals sent, so fix settings and return falsy...
	$_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{IS_LATCHED} = 0;
	if ( exists $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey} ) {
		delete $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE}->{$sigkey};
	}
	if ( scalar keys %{ $_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{NOISE} } == 0 ) {
		$_[HEAP]->{WXPOEIO_CHANNELS}->{$channel}->{IS_NOISY} = 0;
	}
	return 0;
}

# wait kernel call to session here
sub _wait_to_poe {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	if( exists $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WAIT_LOCK} and $_[HEAP]->{SIGNAL_KEY_HREF}->{ $sigkey }->{WAIT_LOCK}) {
		$_[KERNEL]->delay('_MANAGE_TO_POE' => 1, $sigkey, $sigvalue);
		return 1;
	}
	return 1;
}

# timeout latch here
sub _wait_on_latch {
	# ARG0 = signal_key, ARG1 = signal_value
	my( $sigkey, $sigvalue ) = @_[ ARG0, ARG1 ];

	if( !exists $_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_LATCH} and !$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{WAIT_LATCH}) {
		$_[HEAP]->{SIGNAL_KEY_HREF}->{$sigkey}->{LATCH_ATTEMPTS} = 0;
		$_[KERNEL]->yield('_MANAGE_TO_POE', $sigkey, $sigvalue);
		$_[KERNEL]->delay('_MANAGE_LATCHING' => undef, $sigkey, $sigvalue);
		return 1;
	}
	$_[KERNEL]->delay('_MANAGE_LATCHING' => 1, $sigkey, $sigvalue);
	return 1;
}

# Starts the WxPoe IO
sub StartIO {
	# Create an alias for ourself
	$_[KERNEL]->alias_set( $_[HEAP]->{'ALIAS'} );

	# All done!
	return 1;
}

# Stops the WxPoe IO
sub StopIO {
	# Remove our alias
	$_[KERNEL]->alias_remove( $_[HEAP]->{'ALIAS'} );

	# Clear our data
	delete $_[HEAP]->{'WXPOEIO'};
	delete $_[HEAP]->{'WXFRAMEIO'};

	# All done!
	return 1;
}

sub export_queue_ptr {
	my $queue_var = $_[ ARG0 ];
	if(!exists $_[HEAP]->{WXPOEIO_QUEUE}) {
		$_[HEAP]->{WXPOEIO_QUEUE} = [];
	}
	$queue_var = $_[HEAP]->{WXPOEIO_QUEUE};
	return 1;
}

# End of module
1;
