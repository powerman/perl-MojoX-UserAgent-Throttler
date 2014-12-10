package MojoX::UserAgent::Throttler;

use Mojo::Base -strict;

use version; our $VERSION = qv('0.1.0');    # REMINDER: update Changes

# REMINDER: update dependencies in Build.PL
use Mojo::UserAgent;
use Mojo::Util qw( monkey_patch );
use Sub::Util 1.40 qw( set_subname );
use Sub::Throttler 0.002000 qw( throttle_me throttle_me_sync done_cb );


# https://github.com/kraih/mojo/issues/663
# Inconsistent behavior of Mojo::UserAgent::DESTROY:
# - sync requests always executed, even when started while DESTROY
# - for all active async requests which was started before DESTROY user's
#   callback will be called with error in $tx
# - for all async requests which was started while DESTROY user's callback
#   won't be called
# To emulate this behaviour with throttling:
# - sync request: always executed, even when started while DESTROY
# - new async request while DESTROY: ignored
# - delayed async request (it was delayed before DESTROY):
#   * if it start before DESTROY: let Mojo::UserAgent handle it using
#     done_cb($done,$cb)
#   * if it start while DESTROY: do $done->(0) and call user's callback
#     with error in $tx
#   * if it still delayed after DESTROY: call user's callback with error
#     in $tx

use constant START_ARGS => 3;

my %Delayed;        # $ua => { $tx => [$tx, $cb], … }
my %IsDestroying;   # $ua => 1

my $ORIG_start  = \&Mojo::UserAgent::start;
my $ORIG_DESTROY= \&Mojo::UserAgent::DESTROY;

monkey_patch 'Mojo::UserAgent',
start => set_subname('Mojo::UserAgent::start', sub {
    # WARNING Async call return undef instead of (undocumented) connection $id.
    ## no critic (ProhibitExplicitReturnUndef)
    my ($self, $tx, $cb) = @_;
    if (START_ARGS == @_ && $cb) {
        if ($IsDestroying{ $self }) {
#             $cb->($self, $tx->client_close(1)); # to fix issue 663 or not to fix?
            return undef;
        }
        else {
            $Delayed{ $self }{ $tx } = [ $tx, $cb ];
        }
    }
    my $done = ref $_[-1] eq 'CODE' ? &throttle_me || return undef : &throttle_me_sync;
    ($self, $tx, $cb) = @_;
    if ($cb) {
        if ($IsDestroying{ $self }) {
            $done->(0);
        }
        else {
            delete $Delayed{ $self }{ $tx };
            $self->$ORIG_start($tx, done_cb($done, $cb));
        }
        return undef;
    }
    else {
        $tx = $self->$ORIG_start($tx);
        $done->();
        return $tx;
    }
}),
DESTROY => sub {
    my ($self) = @_;
    $IsDestroying{ $self } = 1;
    for (values %{ delete $Delayed{ $self } || {} }) {
        my ($tx, $cb) = @{ $_ };
        $cb->($self, $tx->client_close(1));
    }
    $self->$ORIG_DESTROY;
    delete $IsDestroying{ $self };
    return;
};


1; # Magic true value required at end of module
__END__

=encoding utf8

=head1 NAME

MojoX::UserAgent::Throttler - add throttling support to Mojo::UserAgent


=head1 SYNOPSIS

    use MojoX::UserAgent::Throttler;
    use Sub::Throttler::SOME_ALGORITHM;

    my $throttle = Sub::Throttler::SOME_ALGORITHM->new(...);
    $throttle->apply_to_methods('Mojo::UserAgent');

=head1 DESCRIPTION

This module helps throttle L<Mojo::UserAgent> using L<Sub::Throttler>.

While in most cases this module isn't needed and existing functionality of
Sub::Throttler is enough to throttle Mojo::UserAgent, there are two
special cases which needs extra handling - when B<Mojo::UserAgent object
is destroyed while there are delayed requests>, and when B<new async
requests start while destroying Mojo::UserAgent object>.

To handle these cases it won't be enough to just do usual:

    throttle_it('Mojo::UserAgent::start');

Instead you'll have to write L<Sub::Throttler/"custom wrapper"> plus add
wrapper for Mojo::UserAgent::DESTROY. Both are provided by this module and
activated when you load it.

So, when using this module you shouldn't manually call throttle_it() like
shown above - just use this module and then setup throttling algorithms as
you need and apply them to L<Mojo::UserAgent/"start"> - this will let you
throttle all (sync/async, GET/POST/etc.) requests.
Use L<Sub::Throttler::algo/"apply_to"> to customize throttling based on
request method, hostname, etc.

=head2 EXAMPLE

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
                return { host => $tx->req->url->host };
            } else {
                return { ua_method => "$this " . uc $tx->req->method };
            }
        }
        return;
    });


=head1 BUGS AND LIMITATIONS

No bugs have been reported.


=head1 SUPPORT

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MojoX-UserAgent-Throttler>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

You can also look for information at:

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MojoX-UserAgent-Throttler>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MojoX-UserAgent-Throttler>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MojoX-UserAgent-Throttler>

=item * Search CPAN

L<http://search.cpan.org/dist/MojoX-UserAgent-Throttler/>

=back


=head1 AUTHOR

Alex Efros  C<< <powerman@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Alex Efros <powerman@cpan.org>.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

