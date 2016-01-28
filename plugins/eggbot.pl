use 5.010;
my $isfreenode = 1;

sub eggbot_INIT {
    my ($sock) = @_;
    say "LOADED EGGBOT OMGZZZ ($sock)";
}

sub eggbot_CHANMSG {
    my ($chan, $nick, $ident, $host, $command) = @_;
    my $hostmask = "${ident}\@${host}";
    for ($command) {
        if (/hello/) {
            snd "PRIVMSG $chan :Hello, $nick";
        }
        if (/op me/) {
            if (isAdminMsg($hostmask, $chan, $nick)) {
                snd "MODE ${chan} +o ${nick}";
            }
        }
        if (/^kick (.+)/) {
            if (isAdminMsg($hostmask, $chan, $nick)) {
                my @kickargs = split ' ', $1;
                my $kicknick = shift @kickargs;
                if (scalar @kickargs > 1) {
                    snd "KICK ${chan} ${kicknick} :(${nick}) " . join(' ', @kickargs);
                }
                else {
                    snd "KICK ${chan} ${kicknick} :${nick} didn't think to leave a message";
                }
            }
        }

        if (/^topic (.+)/) {
            if (isAdminMsg($hostmask, $chan, $nick)) {
                snd "TOPIC $chan :${1}";
            }
        }
        
        if (/^voice (.+)/) {
            if (isAdminMsg($hostmask, $chan, $nick)) {
                snd "MODE $chan +v $1";
            }
        }
    }
}

sub eggbot_JOIN {
    my ($chan, $nick, $ident, $host) = @_;
    my $hostmask = "${ident}\@${host}";
    my $botname = botname();
    say "-> Checking if $nick is $botname on $chan";
    if ($nick eq $botname) {
        if ($isfreenode) {
            snd "PRIVMSG ChanServ :OP ${chan} ${nick}";
        }
    }
    if (isAdmin($hostmask, $chan, $nick)) {
        snd "MODE $chan +ov $nick $nick";
    }
}

1;
