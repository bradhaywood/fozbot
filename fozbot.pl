use Async;
use IO::Socket::INET;
use 5.010;
use warnings;
use strict;

# auto-flush on socket
$| = 1;

# defines 
my $proc;
my $socket;
my @plugins;
my $botname    = 'fozbot';
my $botserver  = 'irc.freenode.net';
my $botport    = 6667;
my $botchans   = ['#fozbot'];
my $bottrigger = "$botname,";
my $admins     = ["admin\@host", "admin2\@host"];

# functions
sub botname { return $botname; }

sub setTimeout {
    my ($fn, $d) = @_;
    $proc = Async->new(sub { sleep $d; $fn->(); });
}

sub snd {
    my $data = shift;
    print $socket $data . "\r\n";
}

sub trim {
    my $in = shift;
    $in =~ s/^\s+//g;
    $in =~ s/\s+$//g;
    return $in;
}

sub addchan {
    my ($chan) = @_;
    push @$botchans, $chan;
}

sub hostmask {
    my ($nick, $ident, $host) = @_;
    return "${nick}!${ident}\@${host}";
}

sub isAdmin {
    my ($hostmask, $chan, $nick) = @_;
    return 0 unless grep { $hostmask =~ /^$_$/ } @$admins;
    return 1;
}

sub isAdminMsg {
    my ($hostmask, $chan, $nick) = @_;
    unless (grep { $hostmask =~ /^$_$/ } @$admins) {
        snd "PRIVMSG ${chan} :Nice try, ${nick}.";
        return 0;
    }

    return 1;
}
    
$socket = new IO::Socket::INET (
    PeerHost => $botserver,
    PeerPort => $botport,
    Proto => 'tcp',
);
die "cannot connect to the server: $!\n" unless $socket;

# load plugins
if (-d 'plugins') {
    chdir 'plugins';
    my @pluginFiles = glob "*.pl";
    if (scalar @pluginFiles > 0) {
        loadmodule: {
            no strict 'refs';
            my $f;
            my $method;
            for (@pluginFiles) {
                my $plug = $_;
                $plug =~ s/\.pl$//g;
                say "-> Loading plugin '$_'";
                require "$_";

                my $h = {};
                if (main->can("${plug}_TRIGGER")) {
                    my $t = *{"${plug}_TRIGGER"}->($socket);
                    if ($t) {
                        # replace variables
                        $t =~ s/%botname%/$botname/;
                    }
                }

                if (main->can("${plug}_INIT")) {
                    $method = *{"main::${plug}_INIT"};
                    $method->($socket);
                    push @plugins, $plug;
                }
            }
        }
    }
    chdir '..';
}

setTimeout(sub {
    snd "NICK ${botname}";
    snd "USER ${botname} NUL NUL :i am ${botname}";
    say "-> Sending login information";
}, 5);

     
while(my $data = <$socket>) {
    $data = trim $data;
    say "(Server): ${data}";
    my @args = split ' ', $data;
    #my $command = substr $args[1], 1;
    my $trigger = $args[1];
    if ($args[0] eq 'PING') {
        snd "PONG " . $args[1];
        say "PONG -> " . $args[1];
    }

    # received end of motd, so now we do stuff
    if ($trigger eq '376' or $trigger eq '422') {
        say "-> End of MOTD. Running onconnect";
        if (-f 'onconnect') {
            open my $fh, '<', 'onconnect'
                or die "Could not open onconnect: $!\n";

            while(my $line = <$fh>) {
                $line = trim $line;
                snd $line;
            }
        }

        setTimeout(sub {
            for my $chan (@{$botchans}) {
                snd "JOIN $chan";
            }
        }, 15);
    }

    # process private messages (channel and priv)
    if ($trigger eq 'PRIVMSG') {
        {
            no strict 'refs';
            my $userhost = $args[0];
            my $target   = $args[2];
            my $first    = $args[3];
            splice @args, 0, 4;
            my $cmd = join ' ', @args;
            # is a channel
            if (substr $target, 1 eq '#') {
                $first = substr $first, 1;
                if ($first eq $bottrigger) {
                    if ($userhost =~ /^:(.+)!(.+)\@(.+)$/) {
                        my ($unick, $uident, $uhost) = ($1, $2, $3);
                        if ($unick and $uident and $uhost) {
                            for my $plug (@plugins) {
                                if (main->can("${plug}_CHANMSG")) {
                                    *{"${plug}_CHANMSG"}->($target, $unick, $uident, $uhost, $cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if ($trigger eq 'JOIN') {
        {
            no strict 'refs';
            my $userhost = $args[0];
            my $target   = $args[2];
            if (substr $target, 0, 1 eq ':') {
                $target = substr $args[2], 1;
            }
            if ($userhost =~ /^:(.+)!(.+)\@(.+)$/) {
                my ($unick, $uident, $uhost) = ($1, $2, $3);
                if ($unick and $uident and $uhost) {
                    for my $plug (@plugins) {
                        if (main->can("${plug}_JOIN")) {
                            *{"${plug}_JOIN"}->($target, $unick, $uident, $uhost);
                        }
                    }
                }
            }
        }
    }
}
