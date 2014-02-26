#!/usr/bin/perl -w
# minimal wxPoe sample with WxPoeIO signal handling
# S.A.P., 2014.02.25

# derived from wxpoe2.pl
# absolutely minimal wxPOE sample
# Ed Heil, 5/5/05

use Wx;
use strict;

package MyDisplay;
use base 'Wx::Frame';
use Wx(
    qw [wxDefaultPosition wxDefaultSize wxVERTICAL wxFIXED_MINSIZE
      wxEXPAND wxALL wxTE_MULTILINE ]
);
use Wx::Event qw(EVT_BUTTON EVT_CLOSE);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{NAME}     = undef;
    $self->{DISPLAY_SETTINGS} = {};
    bless ($self, $class);
    return $self;
}
sub start_display {
    my $self = shift;
    my $wxframe = shift;

    $wxframe->{panel} =
      Wx::Panel->new( $wxframe, -1, wxDefaultPosition, wxDefaultSize, );
    $wxframe->{text} =
      Wx::TextCtrl->new( $wxframe->{panel}, -1, '', wxDefaultPosition,
        wxDefaultSize, wxTE_MULTILINE );
    $wxframe->{text_show} =
      Wx::TextCtrl->new( $wxframe->{panel}, -1, "Show me text in this box\n", wxDefaultPosition,
        wxDefaultSize, wxTE_MULTILINE );
    $wxframe->{button} =
      Wx::Button->new( $wxframe->{panel}, -1, 'Press me', wxDefaultPosition,
        wxDefaultSize, );
    $wxframe->{button_click} =
      Wx::Button->new( $wxframe->{panel}, -1, 'Click me', wxDefaultPosition,
        wxDefaultSize, );
    $wxframe->{button_ping} =
      Wx::Button->new( $wxframe->{panel}, -1, 'Ping it', wxDefaultPosition,
        wxDefaultSize, );

    # sizer time!
    my $sizer1 = Wx::BoxSizer->new(wxVERTICAL);
    $sizer1->Add( $wxframe->{panel}, 1, wxEXPAND, 0 );
    $wxframe->SetSizer($sizer1);
    $sizer1->SetSizeHints($wxframe);
    my $sizer2 = Wx::BoxSizer->new(wxVERTICAL);
    $sizer2->Add( $wxframe->{text}, 1, wxEXPAND | wxALL, 10 );
    $sizer2->Add( $wxframe->{text_show}, 1, wxEXPAND | wxALL, 10 );
    $sizer2->Add( $wxframe->{button}, 0, wxALL, 6 );
    $sizer2->Add( $wxframe->{button_click}, 0, wxALL, 6 );
    $sizer2->Add( $wxframe->{button_ping}, 0, wxALL, 6 );
    $wxframe->{panel}->SetSizer($sizer2);
    $sizer2->SetSizeHints( $wxframe->{panel} );
    $wxframe->SetSize( [ 300, 450 ] );

    # events
    EVT_BUTTON( $wxframe, $wxframe->{button}, sub { $wxframe->ButtonEvent } );
    EVT_BUTTON( $wxframe, $wxframe->{button_click}, sub { $wxframe->ButtonEvent2 } );
    EVT_BUTTON( $wxframe, $wxframe->{button_ping}, sub { $wxframe->ButtonEvent3 } );
    EVT_CLOSE( $wxframe, \&OnClose );
    return;
}

sub onClose {
    my ( $self, $event ) = @_;
    ## pass through to MyFrame class
    $self->onClose($event);
}

1;

package MyFrame;
use base 'Wx::Frame';
use Wx(
    qw [wxDefaultPosition wxDefaultSize wxVERTICAL wxFIXED_MINSIZE
      wxEXPAND wxALL wxTE_MULTILINE ]
);
use Wx::Event qw(EVT_BUTTON EVT_CLOSE);

sub new {
    my $class = shift;
    my $fname = shift;

    # create a frame
    my $f_name = $fname . ' wxPOE demo';
    my $self  =
      $class->SUPER::new( undef, -1, $f_name, wxDefaultPosition,
        wxDefaultSize, );

	$self->{WXFRAME_IDENT} = $fname;
    $self->{SIGNAL_QUEUE} = undef;
    $self->{MY_SIGNAL} = undef;
    $self->{MY_ALT_SIGNAL} = undef;
    $self->{SIGNAL_REGISTRATION} = {};
    $self->{USE_FRAME_MGR} = undef;

    # create new display object for frame
    my $display = MyDisplay->new($self);
    $self->{DISPLAY_OBJ} = $display;

    push @MyApp::frames, $self;    # stow in main for poe session to use
    return $self;
}
sub init_wxframe {
    my $self = shift;
    my $_wfmgr = shift;
    my $frame_num = shift;

    # signal registrations
    my $signal = 'clickme1';
    my $signal1 = 'ping_thingy';
    my $signal_href = {'INTER_FRAME'=>1};
    my $signal1_href = {'INTER_FRAME'=>0};
	$self->{MY_ALT_SIGNAL} = 'clickme2';
    $self->{MY_SIGNAL} = $signal;
    # define a separate signal for each frame...a bit kludgy...
    if($frame_num == 2) {
        $signal = $self->{MY_ALT_SIGNAL};
		$self->{MY_ALT_SIGNAL} = $self->{MY_SIGNAL};
		$self->{MY_SIGNAL} = $signal;
        $signal_href->{INTER_FRAME} = 1;
    }
    $signal_href->{WXFRAME_IDENT} = $self->{WXFRAME_IDENT};
    $signal1_href->{WXFRAME_IDENT} = $self->{WXFRAME_IDENT};
    if($self->{USE_FRAME_MGR}) {
        $signal1_href->{WXFRAME_MGR_TOGGLE} = 1;
        if(exists $signal1_href->{WXFRAME_IDENT}) {
            delete $signal1_href->{WXFRAME_IDENT};
        }
    } else {
        $signal_href->{WXFRAME_MGR_TOGGLE} = 0;
        $signal_href->{WXFRAME_OBJ} = $self;
        $signal1_href->{WXFRAME_MGR_TOGGLE} = 0;
        $signal1_href->{WXFRAME_OBJ} = $self;
	}
    $signal_href->{WX_METHOD} = 'ShowMyClick';
    $self->signal_registration($signal,$signal_href);
    $signal1_href->{WX_METHOD} = 'ShowMyPing';
    $self->signal_registration($signal1,$signal1_href);

    ## example...not defined in a POE session, so nothing will happen
    if($frame_num == 3) {
        my $signal2 = 'phonehome';
        my $signal1_href = {'INTER_FRAME'=>0};
        $signal1_href->{WXFRAME_IDENT} = $self->{WXFRAME_IDENT};
        $signal1_href->{WX_METHOD} = 'call_home';
        if($self->{USE_FRAME_MGR}) {
			$signal1_href->{WXFRAME_MGR_TOGGLE} = 1;
            if(exists $signal1_href->{WXFRAME_IDENT}) {
                delete $signal1_href->{WXFRAME_IDENT};
            }
		} else {
			$signal1_href->{WXFRAME_MGR_TOGGLE} = 0;
			$signal1_href->{WXFRAME_OBJ} = $self;
        }
		$self->signal_registration($signal2,$signal1_href);
    }

    # start the display process
	my $display = $self->{DISPLAY_OBJ};
    $display->start_display($self);

    return 1;
}
sub frame_ident {
    my $self = shift;
    if( @_ ) { $self->{WXFRAME_IDENT} = shift; }
    return $self->{WXFRAME_IDENT};
}
sub display_handle {
    my $self = shift;
    if( @_ ) { $self->{DISPLAY_OBJ} = shift; }
    return $self->{DISPLAY_OBJ};
}
sub set_signal_queue {
    my $self = shift;
    if( @_ ) { $self->{SIGNAL_QUEUE} = shift; }
    return $self->{SIGNAL_QUEUE};
}
sub push_new_signal {
    my $self = shift;
    my $sq = $self->{SIGNAL_QUEUE};
    if($sq!~/ARRAY/) {
        warn("Something appears to be amiss with the signal queue. [$sq] Not proper type!\n");
        $self->{SIGNAL_QUEUE} = $sq = [];
    }
    if( @_ ) { 
        my ( $sigkey, $sigvalue ) = @_;
        my $sig = {};
        if (!$sigkey) {
            # fail silently
            return undef;
        }
        if (!$sigvalue) {
            # handle gracefully
            $sigvalue = 1;
        }
        $sig->{$sigkey} = $sigvalue;
        push @$sq, $sig;
        return 1;
    }
    # missing signal data, return falsy
    return 0;
}
sub signal_registration {
    my $self = shift;
    if( @_ ) { 
        my ( $sigkey, $sighref ) = @_;
        my $sr = $self->{SIGNAL_REGISTRATION};
        if (!$sigkey) {
            # fail silently
            return undef;
        }
        $sr->{$sigkey} = $sighref;
        return 1;
    }
    return $self->{SIGNAL_REGISTRATION};
}

sub PoeEvent    { 
	if( exists $_[0]->{text}) {
		$_[0]->{text}->AppendText("POE Event.\n"); 
	}
	return;
}
sub ButtonEvent { $_[0]->{text}->AppendText("Button Event.\n"); }
sub ShowMyClick { $_[0]->{text_show}->AppendText("Other Frame Click Event.\n"); }
sub ShowMyPing {
	my $sigkey = $_[1];
    $_[0]->{text_show}->AppendText($_[2]."\n");
}
sub ButtonEvent2 { 
    $_[0]->push_new_signal( $_[0]->{MY_ALT_SIGNAL}, 'BAMM!' ); 
}
sub ButtonEvent3 { 
    $_[0]->push_new_signal( 'ping_thingy', 'BONG!' ); 
}

sub OnClose {
    my ( $self, $event ) = @_;

    # make sure the POE session doesn't try to send events
    # to a nonexistent widget!
    @MyApp::frames = grep { $_ != $self } @MyApp::frames;
    $self->Destroy();
}

1;

package MyApp;

####
## if using a wxframe manager 
# use FrameManager;
####

use base qw(Wx::App);
use vars qw(@frames);

sub OnInit {
    my $self = shift;
    $self->{WXFRAME_MGR} = undef;
    my $f1 = '1st WxPoe Frame';
    my $f2 = '2nd WxPoe Frame';

    ####
    ## Note that most frames require different functions so
    ## creating two identical frames is just a quick demo
    ####
    Wx::InitAllImageHandlers();
    my $frame = MyFrame->new($f1);
    $self->SetTopWindow($frame);
    $frame->Show(1);
    my $frame2 = MyFrame->new($f2);
    $frame2->Show(1);

    ####
    ## if using a wxframe manager 
    # my $_wfmgr = FrameManager->new();
    # $self->wfmgr_handle($_wfmgr);
    ####
 
    1;
}
sub new_frame {
    my $self = shift;
    my $f = 'Another WxPoe Demo Frame';
    my $frame = MyFrame->new($f);
    $self->SetTopWindow($frame);
    $frame->Show(1);
    return 1;
}
sub wfmgr_handle {
    my $self = shift;
    if(@_) { $self->{WXFRAME_MGR} = shift; }
    return $self->{WXFRAME_MGR};
}

1;

package main;
use POE;
use POE::Loop::Wx;
use POE::Session;
use POE::Component::WxPoeIO;

my $wx_poe_App_name = 'MyApp';
## use MyApp::MyWxApp;
my $main_alias = 'main_poe';

my $_wfmgr = undef;
my $signal_queue = [];

# call out some signal keys
# these keys must be coordinated between Wx frames and Poe sessions
my $signal_keys = {};
	$signal_keys->{clickme}		= 1;
	$signal_keys->{clickme1}	= 1;
	$signal_keys->{clickme2}	= 1;
	$signal_keys->{ping_thingy}	= 1;

my $signal_config = {};
	$signal_config->{clickme} = {'SIGNAL_CHANNEL'=> undef,'LATCH'=>1,'TIMEOUT'=>3,'RETRIES'=>10};
	$signal_config->{clickme1} = {'SIGNAL_CHANNEL'=>'FRAME_TO_FRAME','LATCH'=>0,'TIMEOUT'=>0};
	$signal_config->{clickme2} = {'SIGNAL_CHANNEL'=>'FRAME_TO_FRAME','LATCH'=>0,'TIMEOUT'=>0};
	$signal_config->{ping_thingy} = {'SIGNAL_CHANNEL'=>'PINGER','LATCH'=>0};

my $poe_registration = {};
	$poe_registration->{clickme}	= {'INIT_NEW'=>'_init_local_listener','EVT_METHOD'=>'SendNotice'};
	$poe_registration->{clickme1}	= {'INIT_NEW'=>undef,'EVT_METHOD'=>'ShowMyClick','INTER_FRAME'=>1};
	$poe_registration->{clickme2}	= {'INIT_NEW'=>undef,'EVT_METHOD'=>'ShowMyClick','INTER_FRAME'=>1};
	$poe_registration->{ping_thingy}	= {'INIT_NEW'=>undef,'EVT_METHOD'=>'PingIt'};

# The signal queue can be fetched later if needed.
POE::Component::WxPoeIO->new(
	ALIAS		=> 'WxPoeIO',
	SIGNAL_KEYS	=> $signal_keys,
	SIGNAL_QUEUE	=> $signal_queue,
) or die 'Unable to create WxPoeIO';


my $app = $wx_poe_App_name->new();
# not required, but a handy place to put common tasks
## $_wfmgr = $app->wfmgr_handle();

POE::Session->create(
    inline_states => {
        _start => sub {
            # use a init_config state to organized initial setup
            $_[KERNEL]->yield('init_config');

            # start the Heil pulse
            $_[KERNEL]->yield('pulse');
			
			# set an alias to make the 'posts' easier
			$_[KERNEL]->alias_set($main_alias);
        },
        init_config => sub {
            # Configure the signal based on $signal_config (or other user method)
            foreach my $sigkey (keys %$signal_keys) {
                my $sig_args = $signal_config->{$sigkey};
#                $sig_args->{$sigkey} = 1;
                $sig_args->{SIGNAL_KEY} = $sigkey;
                $_[KERNEL]->post( 'WxPoeIO', 'CONFIG_SIGNAL', $sig_args);
            }
            if ( @MyApp::frames ) {
                foreach ( @MyApp::frames ) {
                    my $fid = $_->frame_ident();
					# kludge to fetch frame number.
					my $frame_num = substr($fid, 0, 1);
                    if( !defined $signal_queue) {
                        $_[KERNEL]->post( 'WxPoeIO', 'EXPORT_SIG_QUEUE_PTR', $signal_queue);
                    }
                    $_->set_signal_queue($signal_queue);
                    $_->init_wxframe($_wfmgr,$frame_num);
                    if( !defined $_wfmgr) {
                        my $frame_reg = $_->signal_registration();
                        if(defined $frame_reg) {
                            foreach my $sigkey (keys %$frame_reg) {
                                my $sig_args = $frame_reg->{$sigkey};
                                $sig_args->{SIGNAL_KEY} = $sigkey;
                                $sig_args->{WXFRAME_OBJ} = $_;
                                if( exists $sig_args->{INTER_FRAME} and $sig_args->{INTER_FRAME} ) {
                                    $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME_TO_FRAME', $sig_args);
                                } else {
                                    $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME', $sig_args);
                                }
                            }
                        }
                    }
                }
                if( defined $_wfmgr) {
                    my $frame_reg = $_wfmgr->signal_registration();
                    if(defined $frame_reg) {
                        foreach my $sigkey (keys %$frame_reg) {
                            my $sig_args = $frame_reg->{$sigkey};
                            $sig_args->{$sigkey} = 1;
                            $sig_args->{SIGNAL_KEY} = $sigkey;
                            $sig_args->{WXFRAME_MGR_TOGGLE} = 1;
                            if( exists $sig_args->{INTER_FRAME} and $sig_args->{INTER_FRAME} ) {
                                $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME_TO_FRAME', $sig_args);
                            } else {
                                $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME', $sig_args);
                            }
                        }
                    }
                }
            }
            foreach my $sigkey (keys %$poe_registration) {
                my $sig_args = $poe_registration->{$sigkey};
                $sig_args->{SIGNAL_KEY} = $sigkey;
                if( exists $sig_args->{INTER_FRAME} and $sig_args->{INTER_FRAME}) {
                    # INTER_FRAME indicates that the Poe registration process can be skipped
                    next;
                }
                if( exists $sig_args->{INIT_NEW} and $sig_args->{INIT_NEW}) {
                    # start an event that starts [new] session and obtains the session id
                    my $meth = $sig_args->{INIT_NEW};
                    $_[KERNEL]->yield( $meth, $sig_args );
                } else {
                    $sig_args->{SESSION} = $main_alias;
                    $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_SESSION', $sig_args);
                }
            }
        },
        pulse => sub {
            if (@MyApp::frames) {
                foreach (@MyApp::frames) {
                    # show a POE event in wxFrame
                    $_->PoeEvent('pulse');
                }

                # relaunch pulse if frames still exist
                $_[KERNEL]->delay( pulse => 3 );

                # Manage signals!
                $_[KERNEL]->post( 'WxPoeIO', 'TRIGGER_SIGNALS');
            }
        },
        start_another_frame => sub {
            my $f = $app->new_frame();
            $_[KERNEL]->yield('init_another_frame',$f);
        },
        init_another_frame => sub {
            my $f = $_[ ARG0 ];
            my $fid = $f->frame_ident();
			my $frame_num = 3;
            $f->set_signal_queue($signal_queue);
            $f->init_wxframe($_wfmgr,$frame_num);
            if( !defined $_wfmgr) {
                my $frame_reg = $f->get_frame_registrations();
                if(defined $frame_reg) {
                    foreach my $sigkey (keys %$frame_reg) {
                        my $sig_args = $frame_reg->{$sigkey};
                        $sig_args->{$sigkey} = 1;
                        $sig_args->{WXFRAME_OBJ} = $_;
                        $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME', $sig_args);
                    }
                }
            } else {
                my $frame_reg = $_wfmgr->get_new_frame_registrations();
                if(defined $frame_reg) {
                    foreach my $sigkey (keys %$frame_reg) {
                        my $sig_args = $frame_reg->{$sigkey};
                        $sig_args->{$sigkey} = 1;
                        $sig_args->{WXFRAME_MGR_TOGGLE} = 1;
                        $_[KERNEL]->post( 'WxPoeIO', 'REGISTER_FRAME', $sig_args);
                    }
                }
            }
        },
        PhoneHome => \&phone_app,
        LogMe => \&log_to_yaml,
        PingIt => \&ping_something,
        _init_local_call => \&_init_local_call,
        _init_local_listener => \&_init_local_listener,
    }
);
sub ping_something {
	# Get the arguments
	my ($sigkey,$sigvalue) = @_[ ARG0, ARG1 ];
	## nothing to do yet...
	$sigvalue = 'Ping Thingy is broken';
	$_[KERNEL]->post( 'WxPoeIO', 'END_SIGNAL', $sigkey, $sigvalue);
	return;
}
sub phone_app {
	# Get the arguments
	my ($sigkey,$sigvalue) = @_[ ARG0, ARG1 ];
	## nothing to do yet...
	return;
}
sub log_to_yaml {
	# Get the arguments
	my ($sigkey,$sigvalue) = @_[ ARG0, ARG1 ];
	## nothing to do yet...
	return;
}
sub _init_local_call {
	# Get the arguments
	my $sig_args = $_[ ARG0 ];
	$sig_args->{SESSION} = undef;
	# create a new session
	# set the session id into $sig_args->{SESSION}
	# register the session into WxPoeIO
	$_[KERNEL]->post( 'WxPoeIO', 'REGISTER_SESSION', $sig_args);
}
sub _init_local_listener {
	# Get the arguments
	my $sig_args = $_[ ARG0 ];
	$sig_args->{SESSION} = undef;
	# create a new session
	# set the session id into $sig_args->{SESSION}
	# register the session into WxPoeIO
	$_[KERNEL]->post( 'WxPoeIO', 'REGISTER_SESSION', $sig_args);
}

POE::Kernel->loop_run();
POE::Kernel->run();