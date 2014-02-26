=head1 ABSTRACT

	Very simple IO signaling system for POE and Wx Loops.

=head1 DESCRIPTION

This module is very similiar to the POE::Component::SimpleLog logging system. It uses the same type of 
register/unregister structure. It was partially inspired by the POE: Cookbook - Broadcasting Events and a long bloody fight
of trying to make Wx events talk with POE sessions.

This module does not do generate or react to signal calls, it simply routes them
to the designated place ( Evt methods ). The normal routing is between a Poe session and a Wx window. However,
it is also possible to send signals between two Wx windows.

You have to configure and register a signal that you desire to use. The configuration describes the signal behavior and
channel you want. The default channel is 'MAIN', so no channel declaration is require if using non-conflicting signals.
For routing between Wx window, a special channel 'FRAME_TO_FRAME' is used to indicate that the signal is passed 
directly to another Wx window. The signal must be coordinated on both sides, Poe and Wx, so each side must register.

Registering for a signal sets up a 'watcher' state so that a signal is broadcast to each registered watcher. A signal
can have multiple dispatches, but only one source. Once the signal task has been completed, the task(er) sends a call
to 'end_signal' to clear the signal state and to dispatch any completion notices. The completion notices are registered
normally as a registered [receiving] WxFrame. No special channel is set for Poe to Poe signaling, though that should 
be an easy add, if needed.

This signaling method only transfers a signal [key] with a single piece of signal data. The intent is not to pass data
arrays back and forth. If you need to pass data and state around, then I would use some type of data and state manager
to handle this task. I use shared pointers to state and data objects within my production app.

Note that signals are triggered between Poe and Wx sessions by way of a 'pulse' method per Ed Heil's wxpoe.pl sample code.
Ed's sample code has been modified in the example to integrate the WxPoeIO signal methods. The code changes were cut from
production code so the examples may need minor tweaks to run without warnings.


The standard way to use this module is to do this:

	use POE;
	use POE::Component::WxPoeIO;

	####
	## Declare vars
	####
	my $MyApp_name = 'WxPoeTestApp';
	my $signal_keys = {'signal1'=>1,'signal2'=>2);
	my $signal_queue = [];
	
	POE::Component::WxPoeIO->new( ... );

	my $MyApp = $MyApp_name->new();
	POE::Session->create( ... );

	POE::Kernel->loop_run();
	POE::Kernel->run();

=head2 Starting WxPoeIO

To start WxPoeIO, just call it's 'new' method:

	POE::Component::WxPoeIO->new(
		'ALIAS'			=>	'WxPoeIO',
		'SIGNAL_KEYS'	=>	$signal_keys,
		'SIGNAL_QUEUE'	=>	$signal_queue,
	);

This method will die on error or return success.

This constructor accepts only 3 options.

=over 4

=item C<ALIAS>

This will set the alias WxPoeIO uses in the POE Kernel.
This will default TO "WxPoeIO"

=item C<SIGNAL_KEYS>

This is a hash pointer to a list of signal keys to be configured and registered later.

=item C<SIGNAL_QUEUE>

This is an array pointer to the signal queue that is shared between the Wx windows and the main Poe session.

=back

=head2 Evt_method

This is the subroutine/method declaration that WxPoeIO uses to dispatch signals. It must match an existing 
method within the object or session.

=over 4

=item C<CONFIG_SIGNAL>

	This task accepts 6 arguments:

	SIGNAL_KEY	->	The name/key of the signal to register
	SIGNAL_CHANNEL	->	The channel the signal will use. Provides locking of channel to avoid signal conflicts
	LATCH		->	The signal can be latch until completion to prevent multiple signal sends
	TIMEOUT		->	The timeout in secs until a latch is removed - in case the signal dies in a session
	LOCK		->	The channel can be lock until completion to prevent signal conflicts on the same channel
	RETRIES		->	The number of times the signal will retry a lock before dying and clearing the lock

	Note: TIMEOUT and RETRIES are not both allowed to be null. One or the other will clear the latch/lock. If a
	hang has occurred in a session, this will not be fixed.

	An example:

	$_[KERNEL]->post( 'WxPoeIO', 'CONFIG_SIGNAL',
		SIGNAL_KEY => 'MySig',
		SIGNAL_CHANNEL => 'Start_Remote_Session',
		[LATCH => 1,]
		[LOCK => 1,]
		[TIMEOUT => undef,]
		[RETRIES => 100,]
	);

	The latching and lock is not super complex. The latch prevents new signals with the same key from being
	accepted. The lock allows similar signals to share the same channel (i.e., session method) but keeps new
	signals from stepping on a working session. The lock checks for is_noisy channel (an active session on the
	channel). If is_noisy, then if the channel is not yet locked, it will be locked. Retries kills the signal 
	by clearing all signal states. This does not fix problems within the session that caused signal not to 
	terminate.
  
	A signal must be configure before a session or a frame can register to use that signal. This is an extra
	step, but ensures the Poe sessions and Wx frames are registering for the same thing.

=item C<REGISTER_SESSION>

	This task accepts 3 arguments:

	SIGNAL_KEY	->	The name/key of the signal to register
	SESSION		->	The session where the signal will go ( Also accepts Session ID's )
	EVT_METHOD	->	The method within the session that will be called upon the signal event

	The registering for a signal will fail if one of the above values are undefined.

	The signal must be pre-configured. Registration links the POE session side of the communication.

	Evt_methods that receive the signals will get these:
		ARG0 -> SIGNAL_KEY
		ARG1 -> SIGNAL_VALUE

	Here's an example:

	$_[KERNEL]->post( 'WxPoeIO', 'REGISTER_SESSION',
		SIGNAL_KEY => 'ClickMe',
		SESSION => $_[SESSION],
		EVT_METHOD => 'start_this',
	);

	This is the session subroutine that will get the ClickMe signal
	sub start_this {
		# Get the arguments
		my( $sigkey, $sigvalue ) = @_[ ARG0 .. ARG1 ];

		print STDERR "Signal [$sigkey] want to start this -> [$sigvalue]\n";

	}

=item C<REGISTER_WXFRAME>

	This task accepts 3 to 5 arguments:

	SIGNAL_KEY		->  The name/key of the signal to register
	EVT_METHOD		->  The method within the wxframe that will be called upon the signal event
	[WXFRAME_IDENT]		->  The identification of the wxframe where the 'end signal' will go
	[WXFRAME_MGR_TOGGLE]	->  A toggle to use a wxframe manager to manage method calls
	[WXFRAME_OBJ]		->  The stored pointer to the wxframe object

	The registering for a signal will fail if the SIGNAL_KEY or EVT_METHOD values are undefined.

	The signal must be pre-configured. Registration links the WxFrame side of the communication.

	Evt_methods that receive the logs will get these:
		ARG0 -> SIGNAL_KEY
		ARG1 -> SIGNAL_VALUE

	An example:

	$_[KERNEL]->post( 'WxPoeIO', 'REGISTER_WXFRAME',
		SIGNAL_KEY => 'ClickMe',
		WXFRAME_IDENT => 'Frame 1',
		EVT_METHOD => 'ShowMyClick',
		WXFRAME_MGR_TOGGLE => undef,
	);

	This is the wxframe subroutine that will get the ClickMe signal
	sub ShowMyClick {
		# using the passed in argument array and indexes
		if($_[1]=~/^clickme/i) {
			$_[0]->{text_show}->AppendText($_[2]."\n");
		}
		return;
	}

=item C<TRIGGER_SIGNALS>

	This task uses no arguments:

	This method pulls new signals from the signal queue (shifting the heap array pointer) and sends the 
	signal (and signal value) to the manage_to_poe method. When the queue is empty, the task exits.

	An example:

	$_[KERNEL]->post( 'WxPoeIO', 'TRIGGER_SIGNALS' );

=item C<END_SIGNAL>

	This task accepts 2 arguments:

	ARG0	->	signal key
	ARG1	->	end value

	This method normally completes the signaling task. If the sigal requires no latch or locking then it is not 
	necessary to end the signal. But typically it is appropriate to send back a completion status or to remove 
	locks on the signal channel. Inter wx frame communication will not use an end_signal. This should not be 
	necessary because the signal result should be visually presented to the user.

	An example:

	$_[KERNEL]->post( 'WxPoeIO', 'END_SIGNAL', $sigkey, $endsigvalue );

	Where, $sigkey is the relevant SIGNAL_KEY value. And $endsigvalue is the variable sent back to wxframe.

	NOTE: The type of the $sigvalue is not restricted and there is no checking of this value. As long as both sides
	of the communication can process this variable, you will be fine. This value (variable) is not intended for 
	the passing of large data structures. If you have this need, then you should create a data management object to 
	be shared across wxframes and sessions.

=item C<EXPORT_SIG_QUEUE_PTR>

	The pointer for the signal queue array should be passed in when the module is started. However, a 'default' 
	pointer can be exported (and stored) so that signalkeys are properly pushed onto the HEAP signal queue array.

	An example:

	if( !defined $signal_queue_ptr ) {
	
		$_[KERNEL]->post( 'WxPoeIO', 'EXPORT_SIQ_QUEUE_PTR', $signal_queue_ptr );

	}
	
	The $signal_queue_ptr variable will now match the signal queue array pointer within the POE $_[HEAP];

=item C<SHUTDOWN>

	This is the generic SHUTDOWN routine, it will stop all logging.

	An example:

	$_[KERNEL]->post( 'WxPoeIO', 'SHUTDOWN' );

=back

=head2 WxPoeIO Notes

Case matters. All of the options are uppercase.

You can enable debugging mode by doing this:

	sub POE::Component::WxPoeIO::DEBUG () { 1 }
	use POE::Component::WxPoeIO;

=head2 EXPORT

Nothing.

=head1 SEE ALSO

L<POE>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014 by Sebastian

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Source credit goes to the POE: Cookbook - Broadcasting Events for the signal channel registry concept. The code structure comes from 
the POE::Component::SimpleLog by Apocalypse. The WxPoe and pulse concept is from the wxpoe2.pl example code by Ed Heil.


=cut
