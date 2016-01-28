use 5.010;
my $ducksActive = 0;
my $duckCount = {};
my $ducksShot = 0;

sub duckhunt_INIT {
    my ($sock) = @_;
    say "LOADED DUCK HUNT OMGZZZ ($sock)";
}

sub duckhunt_CHANMSG {
    my ($chan, $nick, $ident, $host, $command) = @_;
    my $hostmask = hostmask($nick, $ident, $host);

    for ($command) {
        if (/bang$/) {
            if ($ducksActive) {
                my $roll = int(rand(6));
                if ($roll == 5) {
                    $ducksShot++;
                    snd "PRIVMSG $chan :${nick} just shot a duck!";
                    if ($duckCount->{"${nick}"}) {
                        $duckCount->{"${nick}"} = $duckCount->{"${nick}"}+1;
                        snd "PRIVMSG $chan :${nick} has shot down [" . $duckCount->{"${nick}"}. "] ducks";
                    }
                    else {
                        $duckCount->{"${nick}"} = 1;
                        snd "PRIVMSG $chan :${nick} has shot down [1] duck";
                    }

                    if ($ducksShot == 5) {
                        snd "PRIVMSG $chan :The rest of the ducks flew away!";
                        $ducksShot = 0;
                        $ducksActive = 0;
                    }
                    
                }
            }
            else {
                snd "PRIVMSG $chan :${nick}, I don't see any ducks about just yet.";
            }
        }
        if (/^quack$/) {
            if (isAdminMsg("${ident}\@${host}", $chan, $nick)) {
                $ducksActive = 1;
                snd "PRIVMSG $chan :Quack, quack! Is that some ducks I see?";
            }
        }
    }
}

1;
