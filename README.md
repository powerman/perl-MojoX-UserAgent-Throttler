[![Build Status](https://travis-ci.org/powerman/perl-MojoX-UserAgent-Throttler.svg?branch=master)](https://travis-ci.org/powerman/perl-MojoX-UserAgent-Throttler)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-MojoX-UserAgent-Throttler/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-MojoX-UserAgent-Throttler?branch=master)

# NAME

MojoX::UserAgent::Throttler - add throttling support to Mojo::UserAgent

# VERSION

This document describes MojoX::UserAgent::Throttler version v1.0.0

# SYNOPSIS

    use MojoX::UserAgent::Throttler;
    use Sub::Throttler::SOME_ALGORITHM;

    my $throttle = Sub::Throttler::SOME_ALGORITHM->new(...);
    $throttle->apply_to_methods('Mojo::UserAgent');

# DESCRIPTION

This module helps throttle [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) using [Sub::Throttler](https://metacpan.org/pod/Sub::Throttler).

While in most cases this module isn't needed and existing functionality of
Sub::Throttler is enough to throttle Mojo::UserAgent, there are two
special cases which needs extra handling - when **Mojo::UserAgent object
is destroyed while there are delayed requests**, and when **new async
requests start while destroying Mojo::UserAgent object**.

To handle these cases it won't be enough to just do usual:

    throttle_it('Mojo::UserAgent::start');

Instead you'll have to write ["custom wrapper" in Sub::Throttler](https://metacpan.org/pod/Sub::Throttler#custom-wrapper) plus add
wrapper for Mojo::UserAgent::DESTROY. Both are provided by this module and
activated when you load it.

So, when using this module you shouldn't manually call throttle\_it() like
shown above - just use this module and then setup throttling algorithms as
you need and apply them to ["start" in Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent#start) - this will let you
throttle all (sync/async, GET/POST/etc.) requests.
Use ["apply\_to" in Sub::Throttler::algo](https://metacpan.org/pod/Sub::Throttler::algo#apply_to) to customize throttling based on
request method, hostname, etc.

## EXAMPLE

    use MojoX::UserAgent::Throttler;
    use Sub::Throttler::Limit;
    my $throttle = Sub::Throttler::Limit->new(limit=>5);
    # Example policy:
    # - don't throttle sync calls
    # - throttle async GET requests by host
    # - throttle other async requests by method, per $ua object
    # I.e. allow up to 5 parallel GET requests to each host globally for
    # all Mojo::UserAgent objects plus up to 5 parallel non-GET requests
    # per each Mojo::UserAgent object.
    $throttle->apply_to(sub {
        my ($this, $name, @params) = @_;
        if (ref $this eq 'Mojo::UserAgent') {
            my ($tx, $cb) = @params;
            if (!$cb) {
                return;
            } elsif ('GET' eq uc $tx->req->method) {
                return { $tx->req->url->host => 1 };
            } else {
                return { "$this " . uc $tx->req->method => 1 };
            }
        }
        return;
    });

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-MojoX-UserAgent-Throttler/issues](https://github.com/powerman/perl-MojoX-UserAgent-Throttler/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-MojoX-UserAgent-Throttler](https://github.com/powerman/perl-MojoX-UserAgent-Throttler)

    git clone https://github.com/powerman/perl-MojoX-UserAgent-Throttler.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=MojoX-UserAgent-Throttler](https://metacpan.org/search?q=MojoX-UserAgent-Throttler)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/MojoX-UserAgent-Throttler](http://cpanratings.perl.org/dist/MojoX-UserAgent-Throttler)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/MojoX-UserAgent-Throttler](http://annocpan.org/dist/MojoX-UserAgent-Throttler)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=MojoX-UserAgent-Throttler](http://matrix.cpantesters.org/?dist=MojoX-UserAgent-Throttler)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/MojoX-UserAgent-Throttler](http://cpants.cpanauthors.org/dist/MojoX-UserAgent-Throttler)

# AUTHOR

Alex Efros &lt;powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2014- by Alex Efros &lt;powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
